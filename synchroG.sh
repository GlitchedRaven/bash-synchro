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

function journal_edit { #$1= journal_path $2=data $3=filename1
  if [[ `cat $1 | grep -c $3` -gt 0 ]] ; then
    sed -i 's|.*'"$3"'.*|'"$2"'|' "$1"
  else
    echo $2 >> $1
  fi
}

function meta_test {
  #Test the metadatas of the files
  meta_success=1 # 1 = success ; -1 = same md5 but different metdata ; 0 = difference btw two files
  if [[ ( `stat -c %a $1` -eq `stat -c %a $2` )  &&  #If files rights are the same
     ( `stat -c %s $1` -eq `stat -c %s $2` )  && # same weight
     ( `stat -c %Y $1` -eq `stat -c %Y $2` ) ]]; then # same date of last mod

    data="$1 $2 `stat -c %a $1` `stat -c %s $1` `stat -c %Y $1`"

    journal_edit $journal_path "$data" $1

    zenity --info \
      --text="Metatest succeeded for $1 and $2 !"
    #echo "Metatest succeeded for $1 and $2 !"

  else #Metatest failed, the files will be compared to the journal
    journal_verif $1 $2
  fi


}

function journal_verif {
  #local j_line=$(cat $journal_path | grep $1)
  local j_rights=$(cat $journal_path | grep $1 | cut -f 3 -d' ')
  local j_weight=$(cat $journal_path | grep $1 | cut -f 4 -d' ')
  local j_date=$(cat $journal_path | grep $1 |cut $j_line -f 5 -d' ')

  if [[ ( `stat -c %a $1` -eq $j_rights )  &&  #If files rights are the same
     ( `stat -c %s $1` -eq $j_weight )  && # same weight
     ( `stat -c %Y $1` -eq $j_date ) ]]; then

       zenity --info \
         --text="$2 is the TRUE heir to the throne !"

       # echo "$2 is the TRUE heir to the throne !"
       cp -p $2 $1
       data="$1 $2 `stat -c %a $1` `stat -c %s $1` `stat -c %Y $1`"
       journal_edit $journal_path "$data" $1


  elif [[ ( `stat -c %a $2` -eq $j_rights )  &&  #If files rights are the same
     ( `stat -c %s $2` -eq $j_weight )  && # same weight
     ( `stat -c %Y $2` -eq $j_date ) ]]; then

       # echo "$1 is the TRUE heir to the throne"

       zenity --info --text="$1 is the TRUE heir to the throne !"
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

function user_choice {
  data='RESOLVED'

  ans=$(zenity --list \
    --title="User choice" \
    --text="$prompt \nSouhaitez vous garder le premier fichier, le second, ou ne rien faire ?"\
    --column "Choix" --column="Choix n°" --column="Fichier" --column="Source" --column="Type de fichier" --column="Date" --column="Taille" --column="Droits" --column="Adresse"\
    --radiolist \
    TRUE "1" "`basename $1`" "`echo $1 | egrep -o 'system.'`" "`type_fich $1`" "`stat -c %Y $1`" "`stat -c %s $1`" "`stat -c %a $1`" "$1" \
    FALSE "2" "`basename $2`" "`echo $2 | egrep -o 'system.'`" "`type_fich $2`" "`stat -c %Y $2`" "`stat -c %s $2`" "`stat -c %a $2`" "$2"\
    FALSE "3" "Ne rien faire" "" "" "" "" "" "" )

  case $ans in
      1)  if [[ -d $2 ]] ; then
            rm -d $2;
          fi
          cp -p $1 $2 ; journal_edit $conflict_path "$data" $1 ; echo "Fichiers copiés."  ;;

      2)  if [[ -d $1 ]] ; then
            rm -d $1;
          fi
        cp -p $2 $1 ; journal_edit $conflict_path "$data" $1; echo "Fichiers copiés." ;;
      3)  zenity --info --text="Les deux fichiers ont été conservés" ;;
      *) zenity --error --text="Entrée invalide." ;;
  esac

}


function conflict_solver {

  while read line ; do
    local fileA=$( echo $line | cut -f 1 -d' ')
    local fileB=$(echo $line | cut -f 2 -d' ')
    local conflict=$(echo $line | cut -f 3 -d' ')

    case $conflict in
      1)  if [[ ( -d $fileA && -f $fileB )]] ; then
          prompt="$fileA est un repertoire, $fileB est un fichier ordinaire"
          user_choice $fileA $fileB "$prompt"

        else
          prompt=" $fileB est un repertoire, $fileA est un fichier ordinaire "
          user_choice $fileA $fileB "$prompt"
        fi
          ;;

      2)  prompt=" $fileA et $fileB ne sont en conflit que sur les métadonnées"
          user_choice $fileA $fileB "$prompt"
          ;;

      3)  prompt=" $fileA et $fileB diffèrent par leur contenu"
          user_choice $fileA $fileB "$prompt"
          ;;
      RESOLVED) echo "RESOLVED";;
      *) zenity --warning \
        --text="Oups ! Unknown conflict !"
      #echo "Oups ! Unknown conflict !"
          ;;
    esac
  done < $conflict_path
}

function recursive_copy {
  for file in $(ls -a $1) ; do

    if [[ `ls -a $2 | grep -c $file` -eq 0 ]] ; then #Test si le fichier n'existe que dans $1
      if  [[ -d $1$file ]] ; then
        zenity --info \
          --text=""Le repertoire $file sera copié dans $2""
          #echo "Le repertoire $file sera copié dans $2"
        cp -rp $1$file $2



      elif [[ -f $1$file ]] ; then
        zenity --info \
          --text="$file sera copié dans $2"
        #echo "$file sera copié dans $2"
        cp -p $1$file $2
      fi


    elif [[ ( -d $1$file ) && ( -d `ls -a $2 | grep $file` ) ]] ; then # repertoire présent dans les deux fs
    zenity --info \
      --text="Recursive copy dans $1$file"
    #echo "Recursive copy dans $1$file"
    recursive_copy $1$file/ $2$file/
    fi
  done
}

function recursive_synchro { #arg $1 filesystem_A $2 filesystem_B
  for fileA in $(ls -a $1) ; do

    if [ `ls -a $2 | grep -c $fileA` -eq 1 ] ; then #Test si le fichier existe dans B et est unique
      fileB=$(ls -a $2 | grep $fileA)

      local fileA=$1$fileA
      local fileB=$2$fileB

      #echo $fileA
      #echo $fileB

      if [[ ( -d $fileA && -f $fileB ) || ( -f $fileA  && -d $fileB ) ]]  ; then #If files are not of teh same type
        data="$fileA $fileB $CON_TYPE"
        journal_edit $conflict_path "$data" $fileA

      elif [[ -d $fileA  &&  -d $fileB ]] ; then
        zenity --info \
          --text="Recursion dans $fileA et $fileB"
        #echo " Recursion dans $fileA et $fileB"
        #Descendre recursivement : rappel de fonction
        recursive_synchro $fileA/ $fileB/

      elif [[ -f $fileA  &&  -f $fileB ]] ; then
        meta_test $fileA $fileB
      else
        zenity --warning \
          --text="Everithing failed."
        #echo "Everything failed"
      fi
  fi
  done
}


recursive_copy $filesystem_A $filesystem_B
recursive_copy $filesystem_B $filesystem_A
recursive_synchro $filesystem_A $filesystem_B
conflict_solver
