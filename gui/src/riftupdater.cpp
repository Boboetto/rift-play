#include "riftupdater.h"

#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QVersionNumber>

#ifdef CHIAKI_HAVE_DBUS
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#endif

Q_LOGGING_CATEGORY(riftUpdater, "riftplay.updater");

static const char *PORTAL_SERVICE = "org.freedesktop.portal.Flatpak";
static const char *PORTAL_PATH = "/org/freedesktop/portal/Flatpak";
static const char *PORTAL_IFACE = "org.freedesktop.portal.Flatpak";
static const char *MONITOR_IFACE = "org.freedesktop.portal.Flatpak.UpdateMonitor";
// ARM (RP6) and x86_64 (Steam Deck / PC) are released separately:
// v* tags are the ARM build (and GitHub's "latest" release), deck-v* tags the x86_64 build.
#if defined(__x86_64__)
static const char *GITHUB_RELEASES = "https://api.github.com/repos/Boboetto/rift-play/releases?per_page=30";
static const char *RELEASE_TAG_PREFIX = "deck-v";
static const char *BUNDLE_NAME = "RiftPlay-x86_64.flatpak";
#else
static const char *GITHUB_RELEASES = "https://api.github.com/repos/Boboetto/rift-play/releases/latest";
static const char *RELEASE_TAG_PREFIX = "v";
static const char *BUNDLE_NAME = "RiftPlay-aarch64.flatpak";
#endif

RiftUpdater::RiftUpdater(QObject *parent)
    : QObject(parent)
{
}

QString RiftUpdater::currentVersion() const
{
    return QCoreApplication::applicationVersion();
}

QString RiftUpdater::bundleName() const
{
    return QString::fromLatin1(BUNDLE_NAME);
}

void RiftUpdater::start()
{
    // give the app a few seconds to settle before touching the network
    QTimer::singleShot(4000, this, [this]() {
        if (qEnvironmentVariableIsSet("FLATPAK_ID"))
            startPortalMonitor();
        checkGitHub();
    });
}

void RiftUpdater::startPortalMonitor()
{
#ifdef CHIAKI_HAVE_DBUS
    QDBusMessage msg = QDBusMessage::createMethodCall(PORTAL_SERVICE, PORTAL_PATH, PORTAL_IFACE, "CreateUpdateMonitor");
    msg << QVariantMap();
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QDBusObjectPath> reply = *w;
        w->deleteLater();
        if (reply.isError()) {
            qCInfo(riftUpdater) << "Flatpak update monitor unavailable:" << reply.error().message();
            return;
        }
        monitor_path = reply.value().path();
        QDBusConnection bus = QDBusConnection::sessionBus();
        bus.connect(PORTAL_SERVICE, monitor_path, MONITOR_IFACE, "UpdateAvailable",
                    this, SLOT(onUpdateAvailable(QVariantMap)));
        bus.connect(PORTAL_SERVICE, monitor_path, MONITOR_IFACE, "Progress",
                    this, SLOT(onProgress(QVariantMap)));
        qCInfo(riftUpdater) << "Watching for updates via" << monitor_path;
    });
#endif
}

void RiftUpdater::onUpdateAvailable(const QVariantMap &info)
{
    qCInfo(riftUpdater) << "Update available:" << info.value("remote_commit").toString();
    portal_available = true;
    emit stateChanged();
}

void RiftUpdater::install()
{
#ifdef CHIAKI_HAVE_DBUS
    if (!portal_available || monitor_path.isEmpty() || is_updating)
        return;
    is_updating = true;
    progress_percent = 0;
    error_message.clear();
    emit stateChanged();

    QDBusMessage msg = QDBusMessage::createMethodCall(PORTAL_SERVICE, monitor_path, MONITOR_IFACE, "Update");
    msg << QString() << QVariantMap();
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<> reply = *w;
        w->deleteLater();
        if (reply.isError()) {
            is_updating = false;
            error_message = reply.error().message();
            emit stateChanged();
        }
    });
#endif
}

void RiftUpdater::onProgress(const QVariantMap &info)
{
    // status: 0 = running, 1 = empty (nothing to do), 2 = done, 3 = failed
    const uint status = info.value("status").toUInt();
    const uint n_ops = info.value("n_ops").toUInt();
    const uint op = info.value("op").toUInt();
    const uint op_progress = info.value("progress").toUInt();
    if (n_ops > 0)
        progress_percent = int((op * 100 + op_progress) / n_ops);
    else
        progress_percent = int(op_progress);

    if (status == 2 || status == 1) {
        is_updating = false;
        is_finished = true;
        progress_percent = 100;
    } else if (status == 3) {
        is_updating = false;
        error_message = info.value("error_message").toString();
        if (error_message.isEmpty())
            error_message = info.value("error").toString();
    }
    emit stateChanged();
}

void RiftUpdater::checkGitHub()
{
    if (!network)
        network = new QNetworkAccessManager(this);
    QNetworkRequest req{QUrl(GITHUB_RELEASES)};
    req.setRawHeader("Accept", "application/vnd.github+json");
    req.setRawHeader("User-Agent", "RiftPlay-Updater");
    QNetworkReply *reply = network->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return;
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QString prefix = QString::fromLatin1(RELEASE_TAG_PREFIX);
        QString tag;
        if (doc.isArray()) {
            // newest first: take the first published release of this build
            for (const QJsonValue &v : doc.array()) {
                const QJsonObject rel = v.toObject();
                const QString t = rel.value("tag_name").toString();
                if (!rel.value("draft").toBool() && t.startsWith(prefix)) {
                    tag = t;
                    break;
                }
            }
        } else {
            tag = doc.object().value("tag_name").toString();
        }
        if (!tag.startsWith(prefix))
            return;
        tag.remove(0, prefix.size());
        if (tag.isEmpty())
            return;
        latest_version = tag;
        github_newer = versionNewer(tag, currentVersion());
        qCInfo(riftUpdater) << "Latest release" << tag << "current" << currentVersion() << "newer:" << github_newer;
        emit stateChanged();
    });
}

bool RiftUpdater::versionNewer(const QString &a, const QString &b)
{
    return QVersionNumber::compare(QVersionNumber::fromString(a), QVersionNumber::fromString(b)) > 0;
}
