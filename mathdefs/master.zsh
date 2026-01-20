function def-algebra() {
    print "${M_BOLD}Ein Mengensystem ${M_SYS_A} ${M_BOLD} über ${M_SET_OMEGA} ${M_BOLD} ist eine Algebra:${M_RESET}"
    print "  I.   ${M_SET_OMEGA} ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(Grundmenge)${M_RESET}"
    print "  II.  A ${M_OP_IN} ${M_SYS_A} ${M_OP_RARROW} (${M_SET_OMEGA} ${M_OP_DIFF}A) ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(komplementstabil)${M_RESET}"
    print "  III. A, B ${M_OP_IN} ${M_SYS_A} ${M_OP_RARROW} (A ${M_OP_UNION} B) ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(vereinigungsstabil)${M_RESET}"
    print "  ${M_OP_LRARROW}"
    print "  I.   ${M_SET_OMEGA} ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(Grundmenge)${M_RESET}"
    print "  II.  A ${M_OP_IN} ${M_SYS_A} ${M_OP_RARROW} (${M_SET_OMEGA} ${M_OP_DIFF}A) ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(komplementstabil)${M_RESET}"
    print "  III. A, B ${M_OP_IN} ${M_SYS_A} ${M_OP_RARROW} (A ${M_OP_INTERSECT} B) ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(schnittstabil)${M_RESET}"
    print "  ${M_OP_LRARROW}"
    print "  I.   ${M_SET_OMEGA} ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(Grundmenge)${M_RESET}"
    print "  II.  A, B ${M_OP_IN} ${M_SYS_A} ${M_OP_RARROW} (A${M_OP_DIFF}B) ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(differenzmengenstabil)${M_RESET}"
    print "  III. A, B ${M_OP_IN} ${M_SYS_A} ${M_OP_RARROW} (A ${M_OP_UNION} B) ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(vereinigungsstabil)${M_RESET}"
}

function def-sigma-algebra() {
    print "${M_BOLD}Ein Mengensystem ${M_SYS_A} ${M_BOLD} über ${M_SET_OMEGA} ${M_BOLD} ist eine σ-Algebra:${M_RESET}"
    print "  I.   ${M_SET_OMEGA} ${M_OP_IN} ${M_SYS_A}"
    print "  II.  A ${M_OP_IN} ${M_SYS_A} ${M_OP_RARROW} (${M_SET_OMEGA} ${M_OP_DIFF}A) ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(komplementstabil)${M_RESET}"
    print "  III. A₁, A₂, ... ${M_OP_IN} ${M_SYS_A} ${M_OP_RARROW} ${M_OP_UNIONL}ᵢ₌₁^∞ Aᵢ ${M_OP_IN} ${M_SYS_A}   ${M_DESC}(abzählbar vereinigungsstabil)${M_RESET}"
}

function def-ring() {
    print "${M_BOLD}Ein Mengensystem ${M_SYS_R} ${M_BOLD} über ${M_SET_OMEGA} ${M_BOLD} ist ein Ring:${M_RESET}"
    print "  I.   ${M_SET_EMPTY} ${M_OP_IN} ${M_SYS_R}   ${M_DESC}(Leere Menge)${M_RESET}"
    print "  II.  A, B ${M_OP_IN} ${M_SYS_R} ${M_OP_RARROW} (A${M_OP_DIFF}B) ${M_OP_IN} ${M_SYS_R}   ${M_DESC}(differenzmengenstabil)${M_RESET}"
    print "  III. A, B ${M_OP_IN} ${M_SYS_R} ${M_OP_RARROW} (A ${M_OP_UNION} B) ${M_OP_IN} ${M_SYS_R}   ${M_DESC}(vereinigungsstabil)${M_RESET}"
}

function def-semiring() {
    print "${M_BOLD}Ein Mengensystem ${M_SYS_S} ${M_BOLD} über ${M_SET_OMEGA} ${M_BOLD} ist ein Semiring (Halbring):${M_RESET}"
    print "  I.   ${M_SET_EMPTY} ${M_OP_IN} ${M_SYS_S}   ${M_DESC}(Leere Menge)${M_RESET}"
    print "  II.  A, B ${M_OP_IN} ${M_SYS_S} ${M_OP_RARROW} A ${M_OP_INTERSECT} B ${M_OP_IN} ${M_SYS_S}   ${M_DESC}(schnittstabil)${M_RESET}"
    print "  III. A, B ${M_OP_IN} ${M_SYS_S} ${M_OP_RARROW} B${M_OP_DIFF}A ${M_OP}= ⋃${M_RESET}ᵢ₌₁ⁿ Cᵢ mit paarw. disjunkten Cᵢ ${M_OP_IN} ${M_SYS_S}"
}

function def-dynkinsystem() {
    print "${M_BOLD}Ein Mengensystem ${M_SYS_D} ${M_BOLD} über ${M_SET_OMEGA} ${M_BOLD} heißt Dynkin-System:${M_RESET}"
    print "  I.   ${M_SET_OMEGA} ${M_OP_IN} ${M_SYS_D}"
    print "  II.  A, B ${M_OP_IN} ${M_SYS_D} mit A ${M_OP_SUBSET} B  ${M_OP_RARROW}  B${M_OP_DIFF}A ${M_OP_IN} ${M_SYS_D}"
    print "  III. A₁, A₂, ... ${M_OP_IN} ${M_SYS_D} paarw. disjunkt ${M_OP_RARROW} ${M_OP_UNIONL}ₙ₌₁^∞ Aₙ ${M_OP_IN} ${M_SYS_D}"
}

function def-borel-sigma-algebra() {
    print "${M_BOLD}Die Borel’sche σ-Algebra ${M_SYS_B}(${M_SET_OMEGA})${M_BOLD} ist die kleinste σ-Algebra, die alle offenen Mengen enthält:${M_RESET}"
    print "  I.   ${M_SYS_T} ${M_OP_SUBSETEQ} ${M_SYS_B} (${M_SET_OMEGA})   ${M_DESC}(alle offenen Mengen sind enthalten)${M_RESET}"
    print "  II.  ${M_SYS_B} (${M_SET_OMEGA}) ist eine σ-Algebra über ${M_SET_OMEGA}"
    print "  III. ${M_SYS_B} (${M_SET_OMEGA}) ${M_OP_EQ} σ( ${M_SYS_T} )   ${M_DESC}(von der Topologie erzeugt)${M_RESET}"
}

function def-topologie() {
    print "${M_BOLD}Eine Topologie ${M_SYS_T}${M_RESET} ${M_BOLD}auf ${M_SET_OMEGA}${M_RESET} ${M_BOLD}ist ein Mengensystem mit:${M_RESET}"
    print "  I.   ${M_SET_EMPTY}, ${M_SET_OMEGA} ${M_OP_IN} ${M_SYS_T}"
    print "  II.  A, B ${M_OP_IN} ${M_SYS_T} ${M_OP_IMPLIES} A ${M_OP_INTERSECT} B ${M_OP_IN} ${M_SYS_T}"
    print "  III. ${M_SYS_F} ${M_OP_SUBSET} ${M_SYS_T} ${M_OP_IMPLIES} Union(A | A ${M_OP_IN} ${M_SYS_F}) ${M_OP_IN} ${M_SYS_T}   ${M_DESC}(überabzählbar vereinigungsstabil)${M_RESET}"
    print ""
    print "  • (${M_SET_OMEGA}${M_RESET}, ${M_SYS_T}${M_RESET}) heißt ${M_BOLD}topologischer Raum${M_RESET}."
    print "  • A heißt ${M_BOLD}offen${M_RESET}, falls A ${M_OP_IN} ${M_SYS_T}."
    print "  • A heißt ${M_BOLD}abgeschlossen${M_RESET}, falls A${M_OP_COMPLEMENT} ${M_OP_IN} ${M_SYS_T} (bzw. ${M_SET_OMEGA}${M_RESET}${M_OP_DIFF}A ${M_OP_IN} ${M_SYS_T})."
}

function def-inhalt-praemass-mass-wmass() {
    print "${M_BOLD}Sei ${M_SYS_A} ${M_BOLD} ein Semiring und ${M_SYS}μ : 𝒜 → [0, ∞]${M_RESET} ${M_BOLD} mit ${M_SYS}μ(∅) = 0${M_RESET} ${M_BOLD}. Dann heißt ${M_SYS}μ${M_RESET}:${M_RESET}"
    print "  I.   ${M_BOLD}Inhalt${M_RESET}, falls ${M_SYS}μ${M_RESET} additiv ist"
    print "  II.  ${M_BOLD}Prämaß${M_RESET}, falls ${M_SYS}μ${M_RESET} σ-additiv ist"
    print "  III. ${M_BOLD}Maß${M_RESET}, falls ${M_SYS}μ${M_RESET} ein Prämaß ist und ${M_SYS_A}  eine σ-Algebra"
    print "  IV.  ${M_BOLD}Wahrscheinlichkeitsmaß${M_RESET}, falls ${M_SYS}μ${M_RESET} ein Maß ist und ${M_SYS}μ(${M_SET_OMEGA}) = 1${M_RESET}"
}

function def-griechisches-alphabet() {
    print "${M_BOLD}Griechisches Alphabet (mit deutscher Aussprache):${M_RESET}"
    print "  Α α  ${M_SYS}Alpha${M_RESET}        ${M_DESC}(al-fa)${M_RESET}"
    print "  Β β  ${M_SYS}Beta${M_RESET}         ${M_DESC}(be-ta)${M_RESET}"
    print "  Γ γ  ${M_SYS}Gamma${M_RESET}        ${M_DESC}(gam-ma)${M_RESET}"
    print "  Δ δ  ${M_SYS}Delta${M_RESET}        ${M_DESC}(del-ta)${M_RESET}"
    print "  Ε ε  ${M_SYS}Epsilon${M_RESET}      ${M_DESC}(ep-si-lon)${M_RESET}"
    print "  Ζ ζ  ${M_SYS}Zeta${M_RESET}         ${M_DESC}(tse-ta)${M_RESET}"
    print "  Η η  ${M_SYS}Eta${M_RESET}          ${M_DESC}(e-ta)${M_RESET}"
    print "  Θ θ  ${M_SYS}Theta${M_RESET}        ${M_DESC}(te-ta)${M_RESET}"
    print "  Ι ι  ${M_SYS}Iota${M_RESET}         ${M_DESC}(jo-ta)${M_RESET}"
    print "  Κ κ  ${M_SYS}Kappa${M_RESET}        ${M_DESC}(kap-pa)${M_RESET}"
    print "  Λ λ  ${M_SYS}Lambda${M_RESET}       ${M_DESC}(lam-da)${M_RESET}"
    print "  Μ μ  ${M_SYS}My${M_RESET}           ${M_DESC}(mü)${M_RESET}"
    print "  Ν ν  ${M_SYS}Ny${M_RESET}           ${M_DESC}(nü)${M_RESET}"
    print "  Ξ ξ  ${M_SYS}Xi${M_RESET}           ${M_DESC}(ksi)${M_RESET}"
    print "  Ο ο  ${M_SYS}Omikron${M_RESET}      ${M_DESC}(o-mi-kron)${M_RESET}"
    print "  Π π  ${M_SYS}Pi${M_RESET}           ${M_DESC}(pi)${M_RESET}"
    print "  Ρ ρ  ${M_SYS}Rho${M_RESET}          ${M_DESC}(ro)${M_RESET}"
    print "  Σ σ  ${M_SYS}Sigma${M_RESET}        ${M_DESC}(sig-ma)${M_RESET}"
    print "  Τ τ  ${M_SYS}Tau${M_RESET}          ${M_DESC}(tau)${M_RESET}"
    print "  Υ υ  ${M_SYS}Ypsilon${M_RESET}      ${M_DESC}(üp-si-lon)${M_RESET}"
    print "  Φ φ  ${M_SYS}Phi${M_RESET}          ${M_DESC}(fi)${M_RESET}"
    print "  Χ χ  ${M_SYS}Chi${M_RESET}          ${M_DESC}(chi)${M_RESET}"
    print "  Ψ ψ  ${M_SYS}Psi${M_RESET}          ${M_DESC}(psi)${M_RESET}"
    print "  ${M_SET_OMEGA} ${M_SET_OMEGA}  ${M_SYS}Omega${M_RESET}        ${M_DESC}(o-me-ga)${M_RESET}"
}

function def-hebraeisches-alphabet() {
    print "${M_BOLD}Hebräisches Alphabet (mit deutscher Aussprache):${M_RESET}"
    print "  א  ${M_SYS}Aleph${M_RESET}      ${M_DESC}(stumm / glottal)${M_RESET}"
    print "  ב  ${M_SYS}Bet${M_RESET}        ${M_DESC}(b / w)${M_RESET}"
    print "  ג  ${M_SYS}Gimel${M_RESET}      ${M_DESC}(g)${M_RESET}"
    print "  ד  ${M_SYS}Dalet${M_RESET}      ${M_DESC}(d)${M_RESET}"
    print "  ה  ${M_SYS}He${M_RESET}         ${M_DESC}(h)${M_RESET}"
    print "  ו  ${M_SYS}Waw${M_RESET}        ${M_DESC}(w / u / o)${M_RESET}"
    print "  ז  ${M_SYS}Zajin${M_RESET}      ${M_DESC}(s wie in 'Sonne')${M_RESET}"
    print "  ח  ${M_SYS}Chet${M_RESET}       ${M_DESC}(ch, kehlig)${M_RESET}"
    print "  ט  ${M_SYS}Tet${M_RESET}        ${M_DESC}(t)${M_RESET}"
    print "  י  ${M_SYS}Jod${M_RESET}        ${M_DESC}(j)${M_RESET}"
    print "  כ  ${M_SYS}Kaf${M_RESET}        ${M_DESC}(k / ch)${M_RESET}"
    print "  ל  ${M_SYS}Lamed${M_RESET}      ${M_DESC}(l)${M_RESET}"
    print "  מ  ${M_SYS}Mem${M_RESET}        ${M_DESC}(m)${M_RESET}"
    print "  נ  ${M_SYS}Nun${M_RESET}        ${M_DESC}(n)${M_RESET}"
    print "  ס  ${M_SYS}Samech${M_RESET}     ${M_DESC}(s)${M_RESET}"
    print "  ע  ${M_SYS}Ajin${M_RESET}       ${M_DESC}(kehlig / stumm)${M_RESET}"
    print "  פ  ${M_SYS}Pe${M_RESET}         ${M_DESC}(p / f)${M_RESET}"
    print "  צ  ${M_SYS}Zade${M_RESET}       ${M_DESC}(z / ts)${M_RESET}"
    print "  ק  ${M_SYS}Qof${M_RESET}        ${M_DESC}(k, tief)${M_RESET}"
    print "  ר  ${M_SYS}Resch${M_RESET}      ${M_DESC}(r)${M_RESET}"
    print "  ש  ${M_SYS}Schin${M_RESET}      ${M_DESC}(sch / s)${M_RESET}"
    print "  ת  ${M_SYS}Taw${M_RESET}        ${M_DESC}(t)${M_RESET}"
} $