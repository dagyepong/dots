# Feodra spec for HYPE stable releases

%global debug_package %{nil}
%global version VERSION_PLACEHOLDER
%global pkg_summary HypeMaterialShell - Material 3 inspired shell for Wayland compositors

Name:           hype
Version:        %{version}
Release:        RELEASE_PLACEHOLDER%{?dist}
Summary:        %{pkg_summary}

License:        MIT
URL:            https://github.com/AvengeMedia/HypeMaterialShell

Source0:        hype-qml.tar.gz

BuildRequires:  gzip
BuildRequires:  wget
BuildRequires:  systemd-rpm-macros

Requires:       (quickshell or quickshell-git)
Requires:       accountsservice
Requires:       hype-cli = %{version}-%{release}
Requires:       dgop

Recommends:     cava
Recommends:     hypesearch
Recommends:     matugen
Recommends:     NetworkManager
Recommends:     qt6-qtmultimedia
Suggests:       cups-pk-helper
Suggests:       qt6ct

%description
HypeMaterialShell (HYPE) is a modern Wayland desktop shell built with Quickshell
and optimized for the niri and hyprland compositors. Features notifications,
app launcher, wallpaper customization, and fully customizable with plugins.

Includes auto-theming for GTK/Qt apps with matugen, 20+ customizable widgets,
process monitoring, notification center, clipboard history, dock, control center,
lock screen, and comprehensive plugin system.

%package -n hype-cli
Summary:        HypeMaterialShell CLI tool
License:        MIT
URL:            https://github.com/AvengeMedia/HypeMaterialShell

%description -n hype-cli
Command-line interface for HypeMaterialShell configuration and management.
Provides native DBus bindings, NetworkManager integration, and system utilities.

%prep
%setup -q -c -n hype-qml

case "%{_arch}" in
  x86_64)
    ARCH_SUFFIX="amd64"
    ;;
  aarch64)
    ARCH_SUFFIX="arm64"
    ;;
  *)
    echo "Unsupported architecture: %{_arch}"
    exit 1
    ;;
esac

# Download hype-cli for target architecture
wget -O %{_builddir}/hype-cli.gz "https://github.com/AvengeMedia/HypeMaterialShell/releases/latest/download/hype-distropkg-${ARCH_SUFFIX}.gz" || {
  echo "Failed to download hype-cli for architecture %{_arch}"
  exit 1
}
gunzip -c %{_builddir}/hype-cli.gz > %{_builddir}/hype-cli
chmod +x %{_builddir}/hype-cli

%build

%install
install -Dm755 %{_builddir}/hype-cli %{buildroot}%{_bindir}/hype

# Shell completions
install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
%{_builddir}/hype-cli completion bash > %{buildroot}%{_datadir}/bash-completion/completions/hype || :
%{_builddir}/hype-cli completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_hype || :
%{_builddir}/hype-cli completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/hype.fish || :

install -Dm644 %{_builddir}/hype-qml/assets/systemd/hype.service %{buildroot}%{_userunitdir}/hype.service

install -Dm644 %{_builddir}/hype-qml/assets/hype-open.desktop %{buildroot}%{_datadir}/applications/hype-open.desktop
install -Dm644 %{_builddir}/hype-qml/assets/hypelogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/hypelogo.svg

install -dm755 %{buildroot}%{_datadir}/quickshell/hype
cp -r %{_builddir}/hype-qml/* %{buildroot}%{_datadir}/quickshell/hype/

rm -rf %{buildroot}%{_datadir}/quickshell/hype/.git*
rm -f %{buildroot}%{_datadir}/quickshell/hype/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/hype/.github
rm -rf %{buildroot}%{_datadir}/quickshell/hype/distro

echo "%{version}" > %{buildroot}%{_datadir}/quickshell/hype/VERSION

%posttrans
# Signal running HYPE instances to reload
pkill -USR1 -x hype >/dev/null 2>&1 || :

%files
%license LICENSE
%doc README.md CONTRIBUTING.md
%{_datadir}/quickshell/hype/
%{_userunitdir}/hype.service
%{_datadir}/applications/hype-open.desktop
%{_datadir}/icons/hicolor/scalable/apps/hypelogo.svg

%files -n hype-cli
%{_bindir}/hype
%{_datadir}/bash-completion/completions/hype
%{_datadir}/zsh/site-functions/_hype
%{_datadir}/fish/vendor_completions.d/hype.fish

%changelog
* CHANGELOG_DATE_PLACEHOLDER AvengeMedia <contact@avengemedia.com> - VERSION_PLACEHOLDER-RELEASE_PLACEHOLDER
- Stable release VERSION_PLACEHOLDER
- Built from GitHub release
