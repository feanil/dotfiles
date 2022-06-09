import XMonad
import XMonad.Util.Run
import XMonad.Util.EZConfig(additionalKeys)
import XMonad.Config.Xfce
import System.IO

-- Use these two to put the master pane on the right
-- https://hackage.haskell.org/package/xmonad-contrib-0.17.0/docs/XMonad-Layout-Reflect.html
import XMonad.Layout.Reflect
import XMonad.Layout.MultiToggle


myLayouts = desktopLayoutModifiers
        $ mkToggle (single REFLECTX)
        $ mkToggle (single REFLECTY)
        $
            (reflectHoriz $ Tall 1 0.03 0.5) -- Put the master pane on the right
        ||| Tall 1 0.03 0.5
        ||| (reflectVert $ Mirror (Tall 1 0.03 0.5)) -- Put the master pane on the bottom
        ||| Mirror (Tall 1 0.03 0.5)
        ||| Full


main = do
     spawnPipe "sleep 2; xfce4-panel -r;"
     spawnPipe "synclient MaxTapTime=0"
     spawnPipe "killall xautolock; xautolock -time 5 -locker 'xdg-screensaver lock';"
     spawnPipe "setxkbmap -option 'ctrl:nocaps'"
     xmonad $ xfceConfig
        { modMask = mod4Mask     -- Rebind Mod to the Windows key
        -- , layoutHook = myLayouts -- Change the possible layouts
        -- , layoutHook = desktopLayoutModifiers $ Mirror (Mirror (Tall 1 0.03 0.5)) -- Change the possible layouts
        , layoutHook = myLayouts
        } `additionalKeys`
        [ ((mod4Mask .|. shiftMask, xK_Return), spawn "xfce4-terminal")
        , ((mod4Mask , xK_p), spawn "rofi -show run")
        , ((mod4Mask .|. shiftMask, xK_l), spawn "xdg-screensaver lock")
        , ((mod4Mask, xK_c), spawn "setxkbmap -option 'ctrl:nocaps'")
        -- Be able to toggle master pane location
        , ((mod4Mask, xK_r), sendMessage $ Toggle REFLECTX)
        , ((mod4Mask .|. shiftMask, xK_r), sendMessage $ Toggle REFLECTY)
        ]
