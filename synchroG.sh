#!/bin/bash


readonly CON_TYPE=1
readonly CON_CONTENT=2
readonly CON_META=3

journal_path=$HOME/projet/.synchro
conflict_path=$HOME/projet/.conflict
filesystem_A=$HOME/projet/systemA/
filesystem_B=$HOME/projet/systemB/

touch $conflict_path
touch $journal_path

var_text=0 #mode console par défaut
for var in "$@"; do #analyse des options
  case $var in
    -g ) var_text=1 ;; #option graphique
  esac
done


function journal_edit { #$1= journal_path $2=data $3=filename1
  if [[ `cat $1 | grep -c $3` -gt 0 ]] ; then
    sed -i 's|.*'"$3"'.*|'"$2"'|' "$1"
  else
    echo $2 >> $1
  fi
}

function affich_text {
  case $var_text in
    0 ) echo $1 ;; #affichage console
    1 ) case $2 in #affichage avec zenity
      1 ) zenity --info --text="$1" ;;
      2 ) zenity --error --text="$1" ;;
      3 ) zenity --warning --text="$1" ;;
    esac ;;
  esac
}

function meta_test {
  #Test the metadatas of the files
  meta_success=1 # 1 = success ; -1 = same md5 but different metdata ; 0 = difference btw two files
  if [[ ( `stat -c %a $1` -eq `stat -c %a $2` )  &&  #If files rights are the same
     ( `stat -c %s $1` -eq `stat -c %s $2` )  && # same weight
     ( `stat -c %Y $1` -eq `stat -c %Y $2` ) ]]; then # same date of last mod

    data="$1 $2 `stat -c %a $1` `stat -c %s $1` `stat -c %Y $1`"

    journal_edit $journal_path "$data" $1

    affich_text "Metatest succeeded for $1 and $2 !" 1
    #echo "Metatest succeeded for $1 and $2 !"

  else #Metatest failed, the files will be compared to the journal
    journal_verif $1 $2
  fi
}


function journal_verif {
  local j_rights=$(cat $journal_path | grep $1 | cut -f 3 -d' ')
  local j_weight=$(cat $journal_path | grep $1 | cut -f 4 -d' ')
  local j_date=$(cat $journal_path | grep $1 |cut $j_line -f 5 -d' ')

  if [[ ( `stat -c %a $1` -eq $j_rights )  &&  #If files rights are the same
     ( `stat -c %s $1` -eq $j_weight )  && # same weight
     ( `stat -c %Y $1` -eq $j_date ) ]]; then

       affich_text "$2 is the legit one." 1

       cp -p $2 $1
       data="$1 $2 `stat -c %a $1` `stat -c %s $1` `stat -c %Y $1`"
       journal_edit $journal_path "$data" $1

  elif [[ ( `stat -c %a $2` -eq $j_rights )  &&  #If files rights are the same
     ( `stat -c %s $2` -eq $j_weight )  && # same weight
     ( `stat -c %Y $2` -eq $j_date ) ]]; then

       affich_text "$2 is the legit one." 1
       cp -p $1 $2
       data="$1 $2 `stat -c %a $1` `stat -c %s $1` `stat -c %Y $1`"
       journal_edit $journal_path "$data" $1

  elif [[ `md5sum $1 | cut -f 1 -d' '` = `md5sum $2 | cut -f 1 -d' '` ]] ; then
    data="$1 $2 $CON_META"
    journal_edit $conflict_path "$data" $1
  else
    data="$1 $2 $CON_CONTENT"
    journal_edit $conflict_path "$data" $1
  fi

function type_fich {
  if [[ -f $1 ]]; then
    typeFich="Fichier ordinaire"
  elif [[ -d $1 ]]; then
      typeFich="Dossier (`ls -1 $1 | wc -l` sous-fichiers)"
    else
      typeFich="Autre."
  fi

  echo "$typeFich"
}

}

function user_choiceG { #version graphique
  data='RESOLVED'

  ans=$(zenity --list \
    --title="User choice" \
    --text="$3 \nSouhaitez vous garder le premier fichier, le second, ou ne rien faire ?"\
    --column "Choix" --column="Choix n°" --column="Fichier" --column="Source" --column="Type de fichier" --column="Date" --column="Taille" --column="Droits" --column="Adresse"\
    --radiolist \
    TRUE "1" "`basename $1`" "`echo $1 | egrep -o 'system.'`" "`type_fich $1`" "`stat -c %Y $1`" "`stat -c %s $1`" "`stat -c %a $1`" "$1" \
    FALSE "2" "`basename $2`" "`echo $2 | egrep -o 'system.'`" "`type_fich $2`" "`stat -c %Y $2`" "`stat -c %s $2`" "`stat -c %a $2`" "$2"\
    FALSE "3" "Ne rien faire" "" "" "" "" "" "" )

  case $ans in
      1) rm -dfr $2;
          cp -pr $1 "`dirname $2`/" ; journal_edit $conflict_path "$data" $1; break ;;
      2) rm -dfr $1;
        cp -pr $2 "`dirname $1`/" ; journal_edit $conflict_path "$data" $1; break ;;
      3)  affich_text "Les deux fichiers ont été conservés" 1 ;;
      *) affich_text "Entrée invalide." 2 ;;
  esac

}

function user_choiceK { #version console
  data='RESOLVED'
  select test in "Conserver $1" "Conserver $2" "Ne rien faire"; do
    affich_text $3 1
    echo "==> $test"
    case $REPLY in
      1) rm -dfr $2;
          cp -pr $1 "`dirname $2`/" ; journal_edit $conflict_path "$data" $1; break ;;
      2) rm -dfr $1;
        cp -pr $2 "`dirname $1`/" ; journal_edit $conflict_path "$data" $1; break ;;
      3)  affich_text "Les deux fichiers ont été conservés" 1 ;;
      *) affich_text "Entrée invalide." 2; break ;;
    esac
  done
}

function user_choice { #envoie vers les différentes versions d'une même fonction (graphique ou en console)
  if [[ $var_text -eq 0 ]]; then
    user_choiceK $1 $2 $3
  elif [[ $var_text -eq 1 ]]; then
    user_choiceG $1 $2 $3
  fi
}

function conflict_solver {

  while read -u 9 line ; do
    local fileA=$( echo $line | cut -f 1 -d' ')
    local fileB=$(echo $line | cut -f 2 -d' ')
    local conflict=$(echo $line | cut -f 3 -d' ')

    case $conflict in
      1) if [[ ( -d $fileA && -f $fileB )]] ; then
          user_choice $fileA $fileB "$fileA est un repertoire, $fileB est un fichier ordinaire."

        else
          user_choice $fileA $fileB "$fileB est un repertoire, $fileA est un fichier ordinaire."
        fi
          ;;

      2) user_choice $fileA $fileB " $fileA et $fileB ne sont en conflit que sur les métadonnées."
          ;;

      3) user_choice $fileA $fileB "$fileA et $fileB diffèrent par leur contenu."
          ;;
      RESOLVED) ;;
      *) affich_text "Oups ! Unknown conflict !" 3
          ;;
    esac
  done 9< $conflict_path
}

function recursive_copy {
  for file in $(ls -A $1) ; do

    if [[ `ls -a $2 | grep -c $file` -eq 0 ]] ; then #Test si le fichier n'existe que dans $1
      if  [[ -d $1$file ]] ; then
        affich_text "Le repertoire $file sera copié dans $2" 1
        cp -rp $1$file $2
      elif [[ -f $1$file ]] ; then
        affich_text "$file sera copié dans $2" var_text 1
        cp -p $1$file $2
      fi

    elif [[ ( -d $1$file ) && ( -d `ls -a $2 | grep $file` ) ]] ; then # repertoire présent dans les deux fs
    affich_text "Recursive copy dans $1$file" 1
    #echo "Recursive copy dans $1$file"
    recursive_copy $1$file/ $2$file/
    fi
  done
}

function recursive_synchro { #arg $1 filesystem_A $2 filesystem_B
  for fileA in $(ls -A $1) ; do

    if [ `ls -a $2 | grep -c $fileA` -eq 1 ] ; then #Test si le fichier existe dans B et est unique
      fileB=$(ls -a $2 | grep $fileA)

      local fileA=$1$fileA
      local fileB=$2$fileB


      if [[ ( -d $fileA && -f $fileB ) || ( -f $fileA  && -d $fileB ) ]]  ; then #If files are not of teh same type
        data="$fileA $fileB $CON_TYPE"
        journal_edit $conflict_path "$data" $fileA

      elif [[ -d $fileA  &&  -d $fileB ]] ; then
        affich_text "Recursion dans $fileA et $fileB" 1
        #Descendre recursivement : rappel de fonction
        recursive_synchro $fileA/ $fileB/

      elif [[ -f $fileA  &&  -f $fileB ]] ; then
        meta_test $fileA $fileB
      else
        affich_text "Everithing failed." 3
      fi
  fi
  done
}


recursive_copy $filesystem_A $filesystem_B
recursive_copy $filesystem_B $filesystem_A
recursive_synchro $filesystem_A $filesystem_B
conflict_solver
