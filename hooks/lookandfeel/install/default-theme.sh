if have_xorg ; then
    sudo tar xvf resources/theme.tar.xz -C $R
    if [ "$PREFERRED_TOOLKIT" = "qt" ]; then
        install_pkg qtcurve
        install_pkg archlinux-themes-kdm
    else
        install_pkg arc-gtk-theme
    fi
    install_pkg xcursor-pinux
    install_pkg xcursor-oxygen

    install_pkg faience-icon-theme
#    install_pkg mint-themes mint-x-icons # TOO SLOW TO LOAD!

    install_pkg ttf-roboto
    install_pkg otf-hack

#    install_pkg sardi-icons
#    install_pkg flatplat-theme
fi
