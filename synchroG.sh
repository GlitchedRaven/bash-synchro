#!/bin/bash
source gui_functions
source util_functions

readonly CON_TYPE=1
readonly CON_CONTENT=2
readonly CON_META=3
readonly CON_READ=4

readonly MODE_CONS=-1
readonly MODE_GUI=1

journal_path=$HOME/projet/.synchro
conflict_path=$HOME/projet/.conflict
filesystem_A=$HOME/projet/systemTest/systemA/
filesystem_B=$HOME/projet/systemTest/systemB/

rm -f $conflict_path
touch $conflict_path
touch $journal_path

var_text=$MODE_CONS #mode console par défaut
verb=0;
for var in "$@"; do #analyse des options
  case $var in
    -g) var_text=$MODE_GUI;; #option graphique
    -s) var_text=$((var_text+1))
  esac
done


function meta_test {
  #Test the metadatas of the files
  meta_success=1 # 1 = success ; 0 = difference btw two files
  if [[ ( `stat -c %a $1` -eq `stat -c %a $2` )  &&  #If files rights are the same
     ( `stat -c %s $1` -eq `stat -c %s $2` )  && # same weight
     ( `stat -c %Y $1` -eq `stat -c %Y $2` ) ]]; then # same date of last mod

    data="$1 $2 `stat -c %a $1` `stat -c %s $1` `stat -c %Y $1`"

    journal_edit $journal_path "$data" $1

    affich_text "Le test de métadonnée a réussi pour $1 et $2 !" 1

  else #Metatest failed, the files will be compared to the journal
    journal_verif $1 $2
  fi
}


function journal_verif { #$1: file1 $2: file2
  local j_rights=$(cat $journal_path | grep $1 | cut -f 3 -d' ')
  local j_weight=$(cat $journal_path | grep $1 | cut -f 4 -d' ')
  local j_date=$(cat $journal_path | grep $1 |cut -f 5 -d' ')


  if [[ ( `stat -c %a $1` -eq $j_rights )  &&  #If files rights are the same
     ( `stat -c %s $1` -eq $j_weight )  && # same weight
     ( `stat -c %Y $1` -eq $j_date ) ]]; then

       affich_text "$2 est le plus récent" 1
       clean_copy $2 $1 $j_rights
       data="$1 $2 `stat -c %a $1` `stat -c %s $1` `stat -c %Y $1`"
       journal_edit $journal_path "$data" $1


  elif [[ ( `stat -c %a $2` -eq $j_rights )  &&  #If files rights are the same
     ( `stat -c %s $2` -eq $j_weight )  && # same weight
     ( `stat -c %Y $2` -eq $j_date ) ]]; then

       affich_text "$1 est le fichier le plus récent" 1
       clean_copy $1 $2 $j_rights
       data="$1 $2 `stat -c %a $1` `stat -c %s $1` `stat -c %Y $1`"
       journal_edit $journal_path "$data" $1

  elif [[ !(-r $1) || !(-r $2)]]; then
    data="$1 $2 $CON_READ"
    journal_edit $conflict_path "$data" $1
  elif [[ `md5sum $1 | cut -f 1 -d' '` = `md5sum $2 | cut -f 1 -d' '` ]] ; then
    data="$1 $2 $CON_META"
    journal_edit $conflict_path "$data" $1
  else
    data="$1 $2 $CON_CONTENT"
    journal_edit $conflict_path "$data" $1
  fi



}

function user_choice { #envoie vers les différentes versions d'une même fonction (graphique ou en console)
  if [[ $var_text -le $MODE_CONS+1  ]]; then
    user_choiceK $1 $2 $3
  elif [[ $var_text -ge $MODE_GUI ]]; then
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
          prompt="$fileA est un repertoire, $fileB est un fichier ordinaire."
          user_choice $fileA $fileB "$prompt"

        else
          prompt="$fileB est un repertoire, $fileA est un fichier ordinaire."
          user_choice $fileA $fileB "$prompt"
        fi
          ;;

      2)  prompt="$fileA et $fileB diffèrent par leur contenu."
          user_choice $fileA $fileB "$prompt"
          ;;

      3)prompt="$fileA et $fileB ne sont en conflit que sur les métadonnées."
        user_choice $fileA $fileB "$prompt"
          ;;
      4)prompt="$fileA et/ou $fileB ne peuvent être lus."
        user_choice $fileA $fileB "$prompt"
          ;;
      RESOLVED) ;;
      *) affich_text "Conflit inconnu" 3
          ;;
    esac
  done 9< $conflict_path
}

function recursive_copy { #$1: filesystem_A $2 : filesystem_B
  for file in $(ls -A $1) ; do

    if [[ `ls -a $2 | grep -c $file` -eq 0 ]] ; then #Test si le fichier n'existe que dans $1
      if  [[ -d $1$file ]] ; then
        affich_text "Le repertoire $file sera copié dans $2" 1
        clean_copy $1$file $2$file `stat -c %a $2`
      elif [[ -f $1$file ]] ; then
        affich_text "$file sera copié dans $2" var_text 1
        clean_copy $1$file $2$file `stat -c %a $2`
      fi

    elif [[ ( -d $1$file ) && ( -d `ls -a $2 | grep $file` ) ]] ; then # repertoire présent dans les deux fs
    affich_text "Copie recursive dans $1$file" 1
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
        affich_text "Everything failed." 3
      fi
  fi
  done
}


recursive_copy $filesystem_A $filesystem_B
recursive_copy $filesystem_B $filesystem_A
recursive_synchro $filesystem_A $filesystem_B
conflict_solver
