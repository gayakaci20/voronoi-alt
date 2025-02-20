; X11 library
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XDrawPoint
extern XFillRectangle
extern XNextEvent

; stdio library
extern printf
extern scanf

; Constantes pour la taille de la fenêtre et des tableaux
%define FENETRE_X        600      ; Différent de l'original
%define FENETRE_Y        600      ; Différent de l'original
%define MAX_ELEMENTS     15000    ; Différent de l'original

; Constantes pour X11
%define EVENT_MASK       131072
%define KEY_PRESS        2
%define CONFIGURE        22

section .data
    message_centres:  db "Nombre de centres à générer? [1-%d] : ", 0
    message_cibles:   db "Nombre de cibles à connecter? [1-%d] : ", 0
    format_entree:    db "%d", 0
    evenements:       times 24 dq 0

section .bss
    couleurs_centres: resd MAX_ELEMENTS
    ; Variables pour X11
    ecran_nom:       resq    1
    ecran_id:        resd    1
    profondeur:      resd    1
    fenetre:         resq    1
    contexte:        resq    1
    
    ; Variables pour les calculs
    nb_centres:      resd    1
    nb_cibles:       resd    1
    pos_x_centres:   resd    MAX_ELEMENTS
    pos_y_centres:   resd    MAX_ELEMENTS
    pos_x_cibles:    resd    MAX_ELEMENTS
    pos_y_cibles:    resd    MAX_ELEMENTS
    distance_min:    resd    1
    centre_proche:   resd    1
    
section .text
global main

; Fonction pour générer un nombre aléatoire
; Entrée: rdi = valeur maximale
; Sortie: rax = nombre aléatoire généré
; Fonction pour générer un nombre aléatoire dans [0, max]
; Entrée: rdi = valeur maximale
; Sortie: rax = nombre aléatoire
generer_aleatoire:
    push rbp
    mov rbp, rsp
    
.retry_rdrand:
    rdrand ax
    jnc .retry_rdrand  ; Si CF=0, on réessaie
    
    movzx rax, ax      ; Convertir en 64 bits
    xor rdx, rdx
    div rdi            ; rax = rax / rdi, rdx = reste
    mov rax, rdx       ; On garde le reste comme valeur aléatoire

    leave
    ret

; Fonction pour générer une couleur aléatoire
generer_couleur_aleatoire:
    push rbp
    mov rbp, rsp
    
.retry_rdrand:
    rdrand eax
    jnc .retry_rdrand        ; Si CF=0, on réessaie
    
    and eax, 0x00FFFFFF  ; Garder seulement les 24 bits de couleur
    or eax, 0xFF000000   ; Assurer l'opacité maximale
    
    leave
    ret
    
.essai:
    rdrand ax
    jnc .essai        ; Si CF=0, on réessaie
    
    movzx rax, ax
    xor rdx, rdx
    div rdi           ; Division par max pour avoir un nombre dans [0,max]
    mov rax, rdx      ; Le reste est notre nombre aléatoire
    
    leave
    ret

; Fonction pour calculer une distance euclidienne
; Entrée: rdi=x1, rsi=y1, rdx=x2, rcx=y2
; Sortie: rax=distance
calculer_distance:
    push rbp
    mov rbp, rsp
    
    ; (x2-x1)^2
    mov rax, rdx
    sub rax, rdi
    imul rax, rax
    
    ; (y2-y1)^2
    mov r8, rcx
    sub r8, rsi
    imul r8, r8
    
    ; Addition des carrés
    add rax, r8
    
    ; Racine carrée avec SSE
    cvtsi2ss xmm0, rax
    sqrtss xmm0, xmm0
    cvtss2si rax, xmm0
    
    leave
    ret

; Fonction pour trouver le centre le plus proche
; Entrée: rdi=x_point, rsi=y_point
; Sortie: rax=indice du centre le plus proche
trouver_centre_proche:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Sauvegarde des coordonnées
    mov r12, rdi
    mov r13, rsi
    
    ; Initialisation
    mov dword[distance_min], 0x7FFFFFFF
    mov dword[centre_proche], 0
    
    ; Parcours des centres
    xor rbx, rbx
.boucle:
    ; Calcul de la distance avec le centre courant
    mov rdi, r12
    mov rsi, r13
    mov edx, dword[pos_x_centres + rbx*4]
    mov ecx, dword[pos_y_centres + rbx*4]
    call calculer_distance
    
    ; Comparaison avec la distance minimale actuelle
    cmp eax, dword[distance_min]
    jae .suivant
    
    mov dword[distance_min], eax
    mov dword[centre_proche], ebx

.suivant:
    inc rbx
    cmp ebx, dword[nb_centres]
    jl .boucle
    
    mov eax, dword[centre_proche]
    
    pop r13
    pop r12
    pop rbx
    leave
    ret

; Fonction principale pour initialiser la fenêtre X11
initialiser_fenetre:
    push rbp
    mov rbp, rsp
    
    ; Création de la connexion X11
    xor rdi, rdi
    call XOpenDisplay
    mov qword[ecran_nom], rax
    
    ; Récupération de l'écran par défaut
    mov rax, qword[ecran_nom]
    mov eax, dword[rax+0xe0]
    mov dword[ecran_id], eax
    
    ; Création de la fenêtre
    mov rdi, qword[ecran_nom]
    mov esi, dword[ecran_id]
    call XRootWindow
    mov rbx, rax
    
    sub rsp, 32
    mov rdi, qword[ecran_nom]
    mov rsi, rbx
    mov rdx, 20
    mov rcx, 20
    mov r8, FENETRE_X
    mov r9, FENETRE_Y
    push 0xFFFFFF
    push 0x000000
    push 1
    call XCreateSimpleWindow
    add rsp, 48
    mov qword[fenetre], rax
    
    ; Configuration des événements
    mov rdi, qword[ecran_nom]
    mov rsi, qword[fenetre]
    mov rdx, EVENT_MASK
    call XSelectInput
    
    ; Affichage de la fenêtre
    mov rdi, qword[ecran_nom]
    mov rsi, qword[fenetre]
    call XMapWindow
    
    ; Création du contexte graphique
    mov rdi, qword[ecran_nom]
    mov rsi, qword[fenetre]
    xor rdx, rdx
    xor rcx, rcx
    call XCreateGC
    mov qword[contexte], rax
    
    leave
    ret

; Nouvelle fonction pour dessiner le diagramme de Voronoï
dessiner_voronoi:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Parcourir chaque pixel de la fenêtre
    xor r14, r14        ; r14 = coordonnée y
.boucle_y:
    xor r15, r15        ; r15 = coordonnée x
.boucle_x:
    ; Trouver le centre le plus proche pour ce pixel
    mov rdi, r15
    mov rsi, r14
    call trouver_centre_proche
    mov r12d, eax       ; r12 = indice du centre le plus proche
    
    ; Utiliser la couleur du centre pour ce pixel
    mov eax, dword[couleurs_centres + r12*4]
    mov rdi, qword[ecran_nom]
    mov rsi, qword[contexte]
    mov edx, eax
    call XSetForeground
    
    ; Dessiner le pixel avec la couleur du centre le plus proche
    mov rdi, qword[ecran_nom]
    mov rsi, qword[fenetre]
    mov rdx, qword[contexte]
    mov ecx, r15d
    mov r8d, r14d
    mov r9d, 1         ; Largeur = 1
    push 1             ; Hauteur = 1
    call XFillRectangle
    add rsp, 8
    
    ; Passer au pixel suivant (x)
    inc r15
    cmp r15, FENETRE_X
    jl .boucle_x
    
    ; Passer à la ligne suivante (y)
    inc r14
    cmp r14, FENETRE_Y
    jl .boucle_y
    
    ; Dessiner les centres en noir pour les mettre en évidence
    mov rdi, qword[ecran_nom]
    mov rsi, qword[contexte]
    mov edx, 0x000000  ; Couleur noire
    call XSetForeground
    
    xor rbx, rbx
.dessiner_centres:
    mov rdi, qword[ecran_nom]
    mov rsi, qword[fenetre]
    mov rdx, qword[contexte]
    mov ecx, dword[pos_x_centres + rbx*4]
    mov r8d, dword[pos_y_centres + rbx*4]
    mov r9d, 3         ; Largeur = 3
    push 3             ; Hauteur = 3
    call XFillRectangle
    add rsp, 8
    
    inc rbx
    cmp ebx, dword[nb_centres]
    jl .dessiner_centres
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

; Optimisation: dessiner le diagramme de Voronoï par blocs
; pour améliorer les performances
dessiner_voronoi_optimise:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Taille des blocs pour l'optimisation
    %define BLOC_TAILLE 4
    
    ; Parcourir chaque bloc de pixels
    xor r14, r14        ; r14 = coordonnée y
.boucle_y:
    xor r15, r15        ; r15 = coordonnée x
.boucle_x:
    ; Trouver le centre le plus proche pour ce bloc (en utilisant le centre du bloc)
    lea rdi, [r15 + BLOC_TAILLE/2]
    lea rsi, [r14 + BLOC_TAILLE/2]
    call trouver_centre_proche
    mov r12d, eax       ; r12 = indice du centre le plus proche
    
    ; Utiliser la couleur du centre pour ce bloc
    mov eax, dword[couleurs_centres + r12*4]
    mov rdi, qword[ecran_nom]
    mov rsi, qword[contexte]
    mov edx, eax
    call XSetForeground
    
    ; Dessiner le bloc avec la couleur du centre le plus proche
    mov rdi, qword[ecran_nom]
    mov rsi, qword[fenetre]
    mov rdx, qword[contexte]
    mov ecx, r15d
    mov r8d, r14d
    mov r9d, BLOC_TAILLE  ; Largeur du bloc
    push BLOC_TAILLE      ; Hauteur du bloc
    call XFillRectangle
    add rsp, 8
    
    ; Passer au bloc suivant (x)
    add r15, BLOC_TAILLE
    cmp r15, FENETRE_X
    jl .boucle_x
    
    ; Passer à la ligne suivante (y)
    add r14, BLOC_TAILLE
    cmp r14, FENETRE_Y
    jl .boucle_y
    
    ; Dessiner les centres en noir pour les mettre en évidence
    mov rdi, qword[ecran_nom]
    mov rsi, qword[contexte]
    mov edx, 0x000000  ; Couleur noire
    call XSetForeground
    
    xor rbx, rbx
.dessiner_centres:
    mov rdi, qword[ecran_nom]
    mov rsi, qword[fenetre]
    mov rdx, qword[contexte]
    mov ecx, dword[pos_x_centres + rbx*4]
    mov r8d, dword[pos_y_centres + rbx*4]
    mov r9d, 3         ; Largeur = 3
    push 3             ; Hauteur = 3
    call XFillRectangle
    add rsp, 8
    
    inc rbx
    cmp ebx, dword[nb_centres]
    jl .dessiner_centres
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret

main:
    push rbp
    mov rbp, rsp
    
    ; Demande du nombre de centres
    mov rdi, message_centres
    mov rsi, MAX_ELEMENTS
    xor rax, rax
    call printf
    
    mov rdi, format_entree
    mov rsi, nb_centres
    xor rax, rax
    call scanf
    
    ; Demande du nombre de cibles (pour compatibilité)
    mov rdi, message_cibles
    mov rsi, MAX_ELEMENTS
    xor rax, rax
    call printf
    
    mov rdi, format_entree
    mov rsi, nb_cibles
    xor rax, rax
    call scanf
    
    ; Initialisation de la fenêtre X11
    call initialiser_fenetre
    
    ; Génération des centres
    xor rbx, rbx
.generer_centres:
    mov rdi, FENETRE_X
    call generer_aleatoire
    mov dword[pos_x_centres + rbx*4], eax
    
    mov rdi, FENETRE_Y
    call generer_aleatoire
    mov dword[pos_y_centres + rbx*4], eax
    
    call generer_couleur_aleatoire
    mov dword[couleurs_centres + rbx*4], eax
    
    inc rbx
    cmp ebx, dword[nb_centres]
    jl .generer_centres
    
    ; Génération des cibles (pour compatibilité)
    xor rbx, rbx
.generer_cibles:
    mov rdi, FENETRE_X
    call generer_aleatoire
    mov dword[pos_x_cibles + rbx*4], eax
    
    mov rdi, FENETRE_Y
    call generer_aleatoire
    mov dword[pos_y_cibles + rbx*4], eax
    
    inc rbx
    cmp ebx, dword[nb_cibles]
    jl .generer_cibles

boucle_evenements:
    mov rdi, qword[ecran_nom]
    mov rsi, evenements
    call XNextEvent
    
    cmp dword[evenements], CONFIGURE
    je dessiner
    
    cmp dword[evenements], KEY_PRESS
    je fermer
    
    jmp boucle_evenements

dessiner:
    ; Dessiner le diagramme de Voronoï (utiliser la version optimisée)
    call dessiner_voronoi_optimise
    
    mov rdi, qword[ecran_nom]
    call XFlush
    jmp boucle_evenements

fermer:
    mov rax, qword[ecran_nom]
    mov rdi, rax
    call XCloseDisplay
    
    mov rsp, rbp
    pop rbp
    xor rdi, rdi
    mov rax, 60
    syscall