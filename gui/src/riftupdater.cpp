#include "riftupdater.h"

#include <QCoreApplication>
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
static const char *GITHUB_LATEST = "https://api.github.com/repos/Boboetto/rift-play/releases/latest";

RiftUpdater::RiftUpdater(QObject *parent)
    : QObject(parent)
{
}

QString RiftUpdater::currentVersion() const
{
    return QCoreApplication::applicationVersion();
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
    QNetworkRequest req{QUrl(GITHUB_LATEST)};
    req.setRawHeader("Accept", "application/vnd.github+json");
    req.setRawHeader("User-Agent", "RiftPlay-Updater");
    QNetworkReply *reply = network->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return;
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        QString tag = obj.value("tag_name").toString();
        if (tag.startsWith('v'))
            tag.remove(0, 1);
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
