import XMonad
import XMonad.Util.Run
import XMonad.Util.EZConfig(additionalKeys)
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.DynamicLog
import Graphics.X11.ExtraTypes.XF86
import System.IO

main = do
     spawnPipe "synclient MaxTapTime=0"
     spawnPipe "synclient TouchpadOff=1"
     spawnPipe "setxkbmap -option 'ctrl:nocaps'"
     xmonad $ defaultConfig
        { manageHook = manageDocks <+> manageHook defaultConfig
        , layoutHook = avoidStruts  $  layoutHook defaultConfig
        , modMask = mod4Mask     -- Rebind Mod to the Windows key
        } `additionalKeys`
	[
		((mod4Mask .|. shiftMask, xK_l), spawn "xscreensaver-command -lock")
	]
