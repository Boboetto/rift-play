#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class QNetworkAccessManager;

/**
 * Rift Play self-updater.
 *
 * Inside Flatpak it uses the org.freedesktop.portal.Flatpak UpdateMonitor
 * (no extra sandbox permissions): the portal tells us when the remote has a
 * newer commit and can install it for us.
 * As a fallback (e.g. installed from an old bundle without an update remote)
 * it checks the latest GitHub release and just reports the new version.
 */
class RiftUpdater : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY stateChanged)
    Q_PROPERTY(bool updating READ updating NOTIFY stateChanged)
    Q_PROPERTY(bool finished READ finished NOTIFY stateChanged)
    Q_PROPERTY(int progress READ progress NOTIFY stateChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY stateChanged)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged)
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)

public:
    explicit RiftUpdater(QObject *parent = nullptr);

    void start();

    bool available() const { return portal_available || github_newer; }
    bool canInstall() const { return portal_available; }
    bool updating() const { return is_updating; }
    bool finished() const { return is_finished; }
    int progress() const { return progress_percent; }
    QString latestVersion() const { return latest_version; }
    QString error() const { return error_message; }
    QString currentVersion() const;

    /** Install the update through the Flatpak portal. */
    Q_INVOKABLE void install();

private slots:
    void onUpdateAvailable(const QVariantMap &info);
    void onProgress(const QVariantMap &info);

private:
    void startPortalMonitor();
    void checkGitHub();
    static bool versionNewer(const QString &a, const QString &b);

    QString monitor_path;
    QNetworkAccessManager *network = nullptr;
    bool portal_available = false;
    bool github_newer = false;
    bool is_updating = false;
    bool is_finished = false;
    int progress_percent = 0;
    QString latest_version;
    QString error_message;

signals:
    void stateChanged();
};
