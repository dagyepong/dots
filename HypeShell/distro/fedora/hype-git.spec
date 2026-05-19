# Spec for HYPE - uses rpkg macros for git builds

%global debug_package %{nil}
%global version {{{ git_repo_version }}}
%global pkg_summary HypeMaterialShell - Material 3 inspired shell for Wayland compositors
%global go_toolchain_version 1.26.1

Name:           hype
Epoch:          2
Version:        %{version}
Release:        1%{?dist}
Summary:        %{pkg_summary}

License:        MIT
URL:            https://github.com/AvengeMedia/HypeMaterialShell
VCS:            {{{ git_repo_vcs }}}
Source0:        {{{ git_repo_pack }}}
Source1:        https://go.dev/dl/go%{go_toolchain_version}.linux-amd64.tar.gz
Source2:        https://go.dev/dl/go%{go_toolchain_version}.linux-arm64.tar.gz

BuildRequires:  git-core
BuildRequires:  gzip
BuildRequires:  make
BuildRequires:  systemd-rpm-macros

# Core requirements
Requires:       (quickshell-git or quickshell)
Requires:       accountsservice
Requires:       hype-cli = %{epoch}:%{version}-%{release}
Requires:       dgop

# Core utilities (Recommended for HYPE functionality)
Recommends:     cava
Recommends:     hypesearch
Recommends:     matugen
Recommends:     quickshell-git

# Recommended system packages
Recommends:     NetworkManager
Recommends:     qt6-qtmultimedia
Suggests:       cups-pk-helper
Suggests:       qt6ct

%description
HypeMaterialShell (HYPE) is a modern Wayland desktop shell built with Quickshell
and optimized for the niri, hyprland, sway, and dwl (MangoWC) compositors. Features notifications,
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
{{{ git_repo_setup_macro }}}

%build
# Build HYPE CLI from source (core/subdirectory)
VERSION="%{version}"
COMMIT=$(echo "%{version}" | grep -oP '[a-f0-9]{7,}' | head -n1 || echo "unknown")

# Use pinned bundled Go toolchain (deterministic across chroots)
case "%{_arch}" in
  x86_64)
    GO_TARBALL="%{_sourcedir}/go%{go_toolchain_version}.linux-amd64.tar.gz"
    ;;
  aarch64)
    GO_TARBALL="%{_sourcedir}/go%{go_toolchain_version}.linux-arm64.tar.gz"
    ;;
  *)
    echo "Unsupported architecture for bundled Go: %{_arch}"
    exit 1
    ;;
esac

rm -rf .go
tar -xzf "$GO_TARBALL"
mv go .go
export GOROOT="$PWD/.go"
export PATH="$GOROOT/bin:$PATH"
export GOTOOLCHAIN=local
go version

cd core
make dist VERSION="$VERSION" COMMIT="$COMMIT"

%install
# Install hype-cli binary (built from source)
case "%{_arch}" in
  x86_64)
    HYPE_BINARY="hype-linux-amd64"
    ;;
  aarch64)
    HYPE_BINARY="hype-linux-arm64"
    ;;
  *)
    echo "Unsupported architecture: %{_arch}"
    exit 1
    ;;
esac

install -Dm755 core/bin/${HYPE_BINARY} %{buildroot}%{_bindir}/hype

# Shell completions
install -d %{buildroot}%{_datadir}/bash-completion/completions
install -d %{buildroot}%{_datadir}/zsh/site-functions
install -d %{buildroot}%{_datadir}/fish/vendor_completions.d
core/bin/${HYPE_BINARY} completion bash > %{buildroot}%{_datadir}/bash-completion/completions/hype || :
core/bin/${HYPE_BINARY} completion zsh > %{buildroot}%{_datadir}/zsh/site-functions/_hype || :
core/bin/${HYPE_BINARY} completion fish > %{buildroot}%{_datadir}/fish/vendor_completions.d/hype.fish || :

# Install systemd user service
install -Dm644 assets/systemd/hype.service %{buildroot}%{_userunitdir}/hype.service

install -Dm644 assets/hype-open.desktop %{buildroot}%{_datadir}/applications/hype-open.desktop
install -Dm644 assets/hypelogo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/hypelogo.svg

# Install shell files to shared data location
install -dm755 %{buildroot}%{_datadir}/quickshell/hype
cp -r quickshell/* %{buildroot}%{_datadir}/quickshell/hype/

# Remove build files
rm -rf %{buildroot}%{_datadir}/quickshell/hype/.git*
rm -f %{buildroot}%{_datadir}/quickshell/hype/.gitignore
rm -rf %{buildroot}%{_datadir}/quickshell/hype/.github
rm -rf %{buildroot}%{_datadir}/quickshell/hype/distro

%posttrans
# Signal running HYPE instances to reload
pkill -USR1 -x hype >/dev/null 2>&1 || :

%files
%license LICENSE
%doc CONTRIBUTING.md
%doc quickshell/README.md
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
{{{ git_repo_changelog }}}
