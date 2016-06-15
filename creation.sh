#!/bin/bash

r=$HOME/projet
mkdir $r/systemTest
mkdir $r/systemTest/systemA ; mkdir $r/systemTest/systemB

a=$r/systemTest/systemA
b=$r/systemTest/systemB

mkdir $a/fichierDossier ; mkdir $b/dossierFichier

touch $a/dossierFichier ; echo "Ceci est un fichier." > $a/dossierFichier
touch $b/fichierDossier ; echo "Ceci est un fichier." >  $b/fichierDossier

touch $a/fichierUnique ; echo "Ce fichier est unique" > $a/fichierUnique
touch $a/fichierUnique2 ; echo "Ce fichier est unique" > $a/fichierUnique2

mkdir $b/dossierUnique
touch $b/dossierUnique/fichierUniqueB ; echo "Ce fichier est unique" > $b/dossierUnique/fichierUniqueB
touch $b/dossierUnique/fichierUnique2B ; echo "Ce fichier est unique" > $b/dossierUnique/fichierUnique2B


touch $a/pareil ; echo "Aucune différence" > $a/pareil
touch $b/pareil ; echo "Aucune différence" > $b/pareil
touch $a/pareil $b/pareil

touch $a/date $b/date
echo "Pas la même date" > $a/date ;


mkdir $a/sousRep; mkdir $b/sousRep

touch $a/sousRep/taille $b/sousRep/taille
echo "Pas la même taille." > $a/sousRep/taille
echo "Pas la même taille !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" > $b/sousRep/taille
touch $a/sousRep/taille $b/sousRep/taille

touch $a/sousRep/droit $b/sousRep/droit
echo "Pas les mêmes droits." > $a/sousRep/droit
echo "Pas les mêmes droits." > $b/sousRep/droit
chmod 000 $a/sousRep/droit
touch $a/sousRep/droit $b/sousRep/droit


touch $a/sousRep/contenu $b/sousRep/contenu
echo "Même contenu" > $a/sousRep/contenu
echo "Même contenu" > $b/sousRep/contenu
touch $a/sousRep/contenu $b/sousRep/contenu

sleep 1
echo "Pas la même date" > $b/date
