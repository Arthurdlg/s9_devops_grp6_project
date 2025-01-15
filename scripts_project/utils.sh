echo "================ Global variables importation"
NAMESPACE="production"
pause_or_exit() {
    echo "Appuyez sur une touche pour continuer ou tapez 'out' pour quitter."
    read -r -n 3 input
    if [[ "$input" == "out" ]]; then
        echo "Sortie du script."
        exit 0
    fi
}
