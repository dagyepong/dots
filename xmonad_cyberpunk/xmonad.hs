import XMonad
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.SetWMName
import XMonad.Hooks.ManageHelpers
import XMonad.Layout.Spacing
import XMonad.Layout.NoBorders
import XMonad.Layout.PerWorkspace
import XMonad.Util.Run(spawnPipe)
import XMonad.Util.EZConfig(additionalKeys)
import System.IO
import qualified XMonad.StackSet as W
import qualified Data.Map as M

-- Cyberpunk Neon Color Scheme
colorBackground = "#0A0A12"
colorBackgroundAlt = "#1A1A2E"
colorForeground = "#E0E0FF"
colorForegroundAlt = "#B8B8FF"
colorNeonBlue = "#00F3FF"
colorNeonPink = "#FF00FF"
colorNeonGreen = "#00FF9D"
colorNeonPurple = "#9D00FF"
colorNeonOrange = "#FF6B00"
colorNeonCyan = "#00FFE0"
colorAlert = "#FF0055"
colorWarning = "#FFAA00"
colorGood = "#00FF55"

-- Main configuration
main = do
    xmproc <- spawnPipe "xmobar ~/.config/xmobar/xmobarrc"
    xmonad $ ewmh defaults
        { manageHook = manageDocks <+> manageHook defaults
        , layoutHook = avoidStruts $ layoutHook defaults
        , logHook = dynamicLogWithPP xmobarPP
            { ppOutput = hPutStrLn xmproc
            , ppTitle = xmobarColor colorNeonCyan "" . shorten 50
            , ppCurrent = xmobarColor colorNeonGreen "" . wrap "[" "]"
            , ppVisible = xmobarColor colorNeonPurple "" . wrap "(" ")"
            , ppUrgent = xmobarColor colorAlert "" . wrap "!" "!"
            , ppHidden = xmobarColor colorForegroundAlt "" . wrap "" ""
            , ppHiddenNoWindows = xmobarColor colorForegroundAlt "" 
            , ppSep = " <fc=" ++ colorNeonBlue ++ ">|</fc> "
            , ppOrder = \(ws:l:t:ex) -> [ws,l] ++ ex
            }
        }

-- Default configuration
defaults = def
    { terminal           = "alacritty"
    , focusFollowsMouse  = True
    , clickJustFocuses   = False
    , borderWidth        = 2
    , modMask            = mod4Mask
    , workspaces         = ["","","","","","","","",""]
    , normalBorderColor  = colorBackgroundAlt
    , focusedBorderColor = colorNeonCyan
    
    -- Key bindings
    , keys = \c -> myKeys c `M.union` keys def c
    
    -- Layouts
    , layoutHook = spacingRaw False (Border 5 5 5 5) True (Border 5 5 5 5) True $ 
        tiled ||| Mirror tiled ||| Full
      where
        tiled   = Tall nmaster delta ratio
        nmaster = 1
        ratio   = 1/2
        delta   = 3/100
    }

-- Custom key bindings
myKeys (XConfig {modMask = modm}) = M.fromList $
    [ ((modm, xK_Return), spawn "alacritty")
    , ((modm, xK_p), spawn "rofi -show drun -theme cyberpunk")
    , ((modm .|. shiftMask, xK_p), spawn "rofi -show window -theme cyberpunk")
    , ((modm, xK_b), sendMessage ToggleStruts)
    , ((modm, xK_f), spawn "firefox")
    , ((modm, xK_e), spawn "thunar")
    , ((modm, xK_q), kill)
    , ((modm .|. shiftMask, xK_r), spawn "xmonad --recompile && xmonad --restart")
    , ((modm .|. shiftMask, xK_q), spawn "bspc quit")
    
    -- Volume control
    , ((0, 0x1008FF12), spawn "pamixer -t")
    , ((0, 0x1008FF11), spawn "pamixer -d 5")
    , ((0, 0x1008FF13), spawn "pamixer -i 5")
    
    -- Brightness control
    , ((0, 0x1008FF02), spawn "brightnessctl set +5%")
    , ((0, 0x1008FF03), spawn "brightnessctl set 5%-")
    
    -- Screenshots
    , ((modm, xK_Print), spawn "flameshot full -p ~/Pictures/Screenshots")
    , ((modm .|. shiftMask, xK_Print), spawn "flameshot gui")
    ]
    ++
    [((m .|. modm, k), windows $ f i)
        | (i, k) <- zip (workspaces defaults) [xK_1 .. xK_9]
        , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]]

-- Startup applications
startupApps = 
    [ "nitrogen --restore"
    , "picom --config ~/.config/picom/picom.conf &"
    , "dunst &"
    , "xfce4-power-manager &"
    , "nm-applet &"
    , "blueman-applet &"
    ]

main = do
    mapM_ spawn startupApps
    xmonad $ defaults
        { startupHook = startupHook defaults >> setWMName "LG3D"
        }