# Spec for HYPE for OpenSUSE/OBS

%global debug_package %{nil}

Name:           hype
Version:        1.2.3
Release:        1%{?dist}
Summary:        HypeMaterialShell - Material 3 inspired shell for Wayland compositors

License:        MIT
URL:            https://github.com/AvengeMedia/HypeMaterialShell
Source0:        hype-source.tar.gz
Source1:        hype-distropkg-amd64.gz
Source2:        hype-distropkg-arm64.gz

BuildRequires:  gzip
BuildRequires:  systemd-rpm-macros

# Core requirements
Requires:       (quickshell or quickshell-git)
Requires:       accountsservice
Requires:       dgop

# Core utilities (Highly recommended for HYPE functionality)
Recommends:     cava
Recommends:     hypesearch
Recommends:     matugen
Recommends:     NetworkManager
Recommends:     qt6-qtmultimedia
Suggests:       cups-pk-helper
Suggests:       qt6ct

%description
HypeMaterialShell (HYPE) is a modern Wayland desktop shell built with Quickshell
and optimized for niri, Hyprland, Sway, and other wlroots compositors. Features
notifications, app launcher, wallpaper customization, and plugin system.

Includes auto-theming for GTK/Qt apps with matugen, 20+ customizable widgets,
process monitoring, notification center, clipboard history, dock, control center,
lock screen, and comprehensive plugin system.

%prep
%setup -q -n HypeMaterialShell-%{version}

%ifarch x86_64
gunzip -c %{SOURCE1} > hype
%endif
%ifarch aarch64
gunzip -c %{SOURCE2} > hype
%endif
chmod +x hype

%build

%install
install -Dm755 hype %{buildroot}%{_bindir}/hype

install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
./hype completion bash > %{buildroot}%{_datadir}/bash-completion/completions/hype || :
./hype completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_hype || :
./hype completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/hype.fish || :

install -Dm644 assets/systemd/hype.service %{buildroot}%{_userunitdir}/hype.service

install -Dm644 assets/hype-open.desktop %{buildroot}%{_datadir}/applications/hype-open.desktop
install -Dm644 assets/hypelogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/hypelogo.svg

install -dm755 %{buildroot}%{_datadir}/quickshell/hype
cp -r quickshell/* %{buildroot}%{_datadir}/quickshell/hype/

rm -rf %{buildroot}%{_datadir}/quickshell/hype/.git*
rm -f %{buildroot}%{_datadir}/quickshell/hype/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/hype/.github
rm -rf %{buildroot}%{_datadir}/quickshell/hype/distro
rm -rf %{buildroot}%{_datadir}/quickshell/hype/core

echo "%{version}" > %{buildroot}%{_datadir}/quickshell/hype/VERSION

%posttrans
# Signal running HYPE instances to reload
pkill -USR1 -x hype >/dev/null 2>&1 || :

%files
%license LICENSE
%doc CONTRIBUTING.md
%doc quickshell/README.md
%{_bindir}/hype
%dir %{_datadir}/fish
%dir %{_datadir}/fish/vendor_completions.d
%{_datadir}/fish/vendor_completions.d/hype.fish
%dir %{_datadir}/zsh
%dir %{_datadir}/zsh/site-functions
%{_datadir}/zsh/site-functions/_hype
%{_datadir}/bash-completion/completions/hype
%dir %{_datadir}/quickshell
%{_datadir}/quickshell/hype/
%{_userunitdir}/hype.service
%{_datadir}/applications/hype-open.desktop
%dir %{_datadir}/icons/hicolor
%dir %{_datadir}/icons/hicolor/scalable
%dir %{_datadir}/icons/hicolor/scalable/apps
%{_datadir}/icons/hicolor/scalable/apps/hypelogo.svg

%changelog
* Mon Dec 16 2025 AvengeMedia <maintainer@avengemedia.com> - 1.0.3-1
- Update to stable v1.0.3 release

* Fri Dec 12 2025 AvengeMedia <maintainer@avengemedia.com> - 1.0.2-1
- Update to stable v1.0.2 release
- Bug fixes and improvements

* Fri Nov 22 2025 AvengeMedia <maintainer@avengemedia.com> - 0.6.2-1
- Stable release build with pre-built binaries
- Multi-arch support (x86_64, aarch64)
