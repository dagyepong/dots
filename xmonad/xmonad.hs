-- ~/.xmonad/xmonad.hs
import XMonad
import XMonad.Util.EZConfig
import XMonad.Util.Run
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Layout.NoBorders
import qualified Data.Map as M
import qualified XMonad.StackSet as W

-- Import the custom color scheme
import Colors

-- Main Xmonad configuration
main :: IO ()
main = xmonad
     . withEasySB (statusBarProp "xmobar" (pure xmobarPP)) defToggleKey
     $ def
    { modMask            = mod4Mask -- Use the Super key as the main modifier
    , terminal           = "urxvt" -- Change to your preferred terminal
    , normalBorderColor  = bg
    , focusedBorderColor = blue
    , workspaces         = myWorkspaces
    , manageHook         = myManageHook
    , layoutHook         = myLayoutHook
    }
    `additionalKeys` myKeys

-- Workspaces with special symbols for a futuristic feel
myWorkspaces :: [String]
myWorkspaces = ["1:term", "2:web", "3:code", "4:chat", "5:gfx"]

-- A simple startup hook for Gentoo/OpenRC
myStartupHook :: X ()
myStartupHook = do
    spawnOnce "feh --bg-fill /path/to/your/cyberpunk-wallpaper.jpg" -- Set a neon-themed wallpaper
    spawnOnce "picom --experimental-backends --fade-in-step=0.03 --fade-out-step=0.03 --fade-delta=4 -b" -- A good compositor for eye candy
    spawnOnce "xmobar" -- Start Xmobar
    spawnOnce "lxpolkit" -- Polkit agent for authentication

-- ManageHook for window rules
myManageHook :: ManageHook
myManageHook = composeAll
    [ className =? "Gimp" --> doFloat
    , className =? "Firefox" --> doShift "2:web"
    , className =? "Code" --> doShift "3:code"
    ]

-- Layout hook with no borders on floating windows
myLayoutHook = smartBorders tiled ||| smartBorders (Mirror tiled) ||| smartBorders Full
  where
    tiled   = Tall 1 (3/100) (1/2)

-- Keybindings for the Xmonad configuration
myKeys :: [(String, X ())]
myKeys =
    [ ("M-p", spawn "dmenu_run -b -fn 'Terminus-12' -nf '#c0c0d0' -nb '#0f0f1b' -sf '#ffff00' -sb '#0f0f1b'")
    , ("M-S-p", spawn "passmenu -l 20")
    , ("M-S-c", kill)
    , ("M-S-r", restart "xmonad" True)
    ]

xmobarPP :: PP
xmobarPP = def
    { ppCurrent = xmobarColor magenta "" . wrap "[" "]"
    , ppVisible = xmobarColor cyan ""
    , ppHidden  = xmobarColor fg ""
    , ppUrgent  = xmobarColor red "" . wrap "{" "}"
    , ppLayout  = xmobarColor yellow ""
    , ppTitle   = xmobarColor cyan "" . shorten 60
    , ppOutput  = putStrLn
    }
