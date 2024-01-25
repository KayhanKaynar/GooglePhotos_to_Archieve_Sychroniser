#!/bin/bash

start=$(date +%s.%N)

clear

###### SCRIPT VARIABLES
dir="/mnt/DATA/Fotograflarim/"                  # Main archive directory
PHOTOJUNK="/mnt/DATA/JUNKPHOTOS"                # Junk photos directory
[ ! -d "$PHOTOJUNK" ] && mkdir "$PHOTOJUNK"


currentHour=$(date +"%H")
# Saat aralıklarına göre değişkeni ayarla
if [ $currentHour -ge 0 -a $currentHour -lt 6 ]; then
    googleID="KayhanGP_1"
elif [ $currentHour -ge 6 -a $currentHour -lt 12 ]; then
    googleID="KayhanGP_2"
elif [ $currentHour -ge 12 -a $currentHour -lt 18 ]; then
    googleID="KayhanGP_3"
else
    googleID="KayhanGP_4"
fi

###### CHECK SYSTEM AND SCRIPT REQUIREMENTS
if [ -z "$dir" ] || [ -z "$PHOTOJUNK" ] || [ -z "$googleID" ]; then
    echo -e "At least one of the global script variables is empty:"
    echo -e "dir      :\t$dir"
    echo -e "PHOTOJUNK:\t$PHOTOJUNK"
    echo -e "googleID :\t$googleID"
    echo -e "\r"
    echo "One of the variables is empty. It has to be defined."
    echo "Exiting.."
    exit 1
fi

PATH=$PATH:"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
currentdate="$(date +%d).$(date +%m).$(date +%Y)_$(date +%H).$(date +%M)"
echo "$currentdate"
echo "Bu script $(basename $0) dosyasindan isletiliyor."

pkgs='rclone'
install=false
for pkg in $pkgs; do
  status="$(dpkg-query -W --showformat='${db:Status-Status}' "$pkg" 2>&1)"
  if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
    install=true
    break
  fi
done
if "$install"; then
  echo "  Rclone package has not been found in your system"
  echo "  Please install it with 'sudo apt install rclone' command."
  echo "  Exiting.."
  exit 1
fi

willdelete=()
mesaj=$(mktemp)
googlerawlist=$(mktemp)
fulllist_google=$(mktemp)
fulllist_google_with_exif=$(mktemp)
fulllist_local=$(mktemp)
onlylocalfilestxt=$(mktemp)
onlyremotefilestxt=$(mktemp)
exifdiff=$(mktemp)
previous_google_with_exif="/root/.config/previous_google_with_exif.txt"

print_empty_line(){
echo -e "\r"
}

kirlangic_check(){
file="$1"
if [[ "$file" == *" {"* && $file == *"}."* ]]; then
file=$(echo "$file" |  cut -d"{" -f 1 | sed -e 's/ //g')
fi
echo $file
}

extension_remove(){
file_name="$1"
base_name="${file_name%.*}"
echo "$base_name"
}

local_exif_date(){
extension=$(echo "$1" | grep -oP '\.\K[^.]{2,3}(?=$)' )
if [ "$extension" == "mp4" ] || [ "$extension" == "MOV" ] || [ "$extension" == "mov" ] || [ "$extension" == "avi" ] || [ "$extension" == "MP4" ]
        then
        output=$(exiftool -T -FileName -MediaCreateDate "$1")
        time_part=$(echo "$output" | grep -oE '[0-9]{4}:[0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -n 1 |  awk '{print $2}' | cut -d':' -f 2,3)
        else
        output=$(exiftool -T -FileName -DateTimeOriginal "$1")
        time_part=$(echo "$output" | grep -oE '[0-9]{4}:[0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -n 1 |  awk '{print $2}' | cut -d':' -f 2,3)
fi
echo "$time_part"
}

rclone lsl "$googleID:album" -P > $googlerawlist

echo "Google rawlist has been created"
print_empty_line

##########  GOOGLE QUOTA CHECK to prevent files in case of not generated google raw list.
grep -e "Quota exceeded" $googlerawlist
if [ $? -eq 0 ]; then
    echo "GOOGLE QUOTA EXCEEDED, can not move forward."
    exit 1
fi

########## GENERATING FULL GOOGLE and GOOGLE EXIF lists/files
cat $googlerawlist | awk -F"-1 " '{print $2}' | grep -v '^[[:space:]]*$' > $fulllist_google_with_exif
cat $googlerawlist | awk -F"-1 " '{print $2}' | grep -v '^[[:space:]]*$' | cut -d'.' -f 2- | cut -d' ' -f 2- > $fulllist_google

########## GENERATING FULL LOCAL list/file
find "$dir" -type f \( ! -name '*.swf' ! -name '*.exe' \) -print |  sed "s|$dir||" > $fulllist_local

echo "Google photo count: $(cat $fulllist_google | wc -l)"
echo "Local  photo count: $(cat  $fulllist_local | wc -l)"
print_empty_line

################ CALCULATE/GENERATE LOCAL LIST ###########
IFS=$'\n' locallist=($(cat $fulllist_local))

grep -Fxv -f "$fulllist_google" "$fulllist_local" > $onlylocalfilestxt
grep -Fxv -f "$fulllist_local" "$fulllist_google" > $onlyremotefilestxt
print_empty_line

################ PRINT ONLY LOCAL and ONLY GOOGLE LISTs:
echo "SADECE GOOGLE da bulunanlar"
IFS=$'\n' onlygoogle=($(cat $onlyremotefilestxt))
printf '%s\n' "${onlygoogle[@]}"
onlygooglecount="${#onlygoogle[@]}"
print_empty_line

echo "SADECE LOKAL de bulunanlar"
IFS=$'\n' onlylocal=($(cat $onlylocalfilestxt))
printf '%s\n' "${onlylocal[@]}"
onlylocalcount="${#onlylocal[@]}"
print_empty_line

################ ONLY GOOGLE EXIF
echo "ONLY GOOGLE EXIF:"
if [ "$onlygooglecount" != "0" ]; then
        for ((i=0; i<onlygooglecount; i++)); do
        c=${onlygoogle[$i]}
        onlygoogleexif=$(grep "$c" "$fulllist_google_with_exif" | grep .000000000 | sed 's/^-1 //' | sed 's/\.[0-0]\+//' | awk '{print $2}' | cut -d':' -f 2,3)
        onlygoogleexifarray+=("$onlygoogleexif")
        printf '%s\n' "$i.exif: $onlygoogleexif , only google $i.eleman: "$c""
        done
else
echo "There is no element on only google list"
print_empty_line
fi
print_empty_line

################ ONLY LOCAL EXIF
generatelocalexif(){
echo "ONLY LOCAL EXIF:"
if [ "$onlylocalcount" != "0" ]; then
        for i in "${!onlylocal[@]}"; do
                b="${onlylocal[$i]}"
                onlylocalexif=$(local_exif_date "$dir$b")
                if [ -z "$onlylocalexif" ]
                then
                echo "$i. oge $b icin localde exif bilgisi bulunamadi."
                else
                onlylocalexifarray+=("$onlylocalexif")
                printf '%s\n' "$i.exif: $onlylocalexif , only local $i.eleman: "$b""
                fi
        done
        print_empty_line
else
echo "There is no element on only local list"
print_empty_line
fi
print_empty_line
}

################ CHECK IF THERE IS ELEMENT ON ONLY GOOGLE ARRAY
if [ "$onlygooglecount" != "0" ]; then
generatelocalexif
else
echo "No need to generate local exif arrays, because there is no element to compare on Only Google list.."
fi

################ COMPARING ELEMENTS
for i in "${!onlygoogle[@]}"; do
element1="${onlygoogle[i]}"
element1_base="$(basename "$element1")"
remoteexif="${onlygoogleexifarray[i]}"
found="false"

        for j in "${!onlylocal[@]}"; do
        element2="${onlylocal[j]}"
        element2_base="$(basename "$element2")"
        onlylocalexif="${onlylocalexifarray[j]}"
        #echo "CP1"

                if [ "$element1_base" == "$element2_base" ]; then
                        #echo "CP2"

                        if [ "$remoteexif" == "$onlylocalexif" ]; then
                        found="true"

                        echo "###########################################################"
                        echo "# --> COPY FROM ONLY_LOCAL                                #"
                        echo "###########################################################"
                        print_empty_line

                        #[ -z "$remoteexif" ] || [ -z "$onlylocalexif" ] && echo "One of the variables has no exif info: remoteexif   :$remoteexif , element1_base:$eleme
nt1_base"
                        #[ -z "$remoteexif" ] || [ -z "$onlylocalexif" ] && echo "One of the variables has no exif info: onlylocalexif:$onlylocalexif , element2_base:$el
ement2_base"
                        #[ -z "$remoteexif" ] || [ -z "$onlylocalexif" ] && print_empty_line

                        echo -e "Element1(Google):\t$element1"
                        echo -e "Element1_base:\t\t$element1_base"
                        echo -e "Remoteexif:\t\t$remoteexif"
                        echo -e "Element2(Local):\t$element2"
                        echo -e "Element2_base:\t\t$element2_base"
                        echo -e "Element2 exif:\t\t$onlylocalexif"
                        print_empty_line

                        echo -e "REMOTE\t$i:\texif:${onlygoogleexifarray["$i"]} \t ${onlygoogle["$i"]}"
                        echo -e "LOCAL\t$j:\texif:${onlylocalexifarray["$j"]} \t ${onlylocal["$j"]}"
                        DIR1="$(dirname "$dir${onlygoogle["$i"]}")"
                        mkdir -p "$DIR1"
                        echo "cp $dir${onlylocal["$j"]} $dir${onlygoogle["$i"]}"
                        cp "$dir${onlylocal["$j"]}" "$dir${onlygoogle["$i"]}"
                        unset "onlygoogle[i]"
                        unset "onlygoogleexifarray[i]"
                        echo "Adding $element2 to delete list..."
                        willdelete+=("$element2")
                        print_empty_line
                        fi
                fi
        done
                if [ "$found" != true ]; then
                                #echo "CP4"
                                unset element3list
                                IFS=$'\n' element3list=($(find $dir -name "*$element1_base*" -type f -print | sed "s|$dir||"))
                                element3_uzunluk="${#element3list[@]}"

                                for ((s=0; s<$element3_uzunluk; s++)); do
                                element3="${element3list[s]}"
                                element3_base="$(basename "${element3list[s]}")"
                                element3_exif=$(local_exif_date "$dir/${element3list[s]}")

                                if [ "$element1_base" == "$element3_base" ]; then
                                        if [ "$remoteexif" == "$element3_exif" ]; then
                                        found=true

                                        echo "###########################################################"
                                        echo "# --> COPY FROM ARCHIEVE                                  #"
                                        echo "###########################################################"
                                        print_empty_line

                                        echo "Aradigimiz dosya: $element1_base (exif: $remoteexif) icin arsivde bulunan eleman sayisi: $element3_uzunluk ve buldugum elemanlar:"
                                        printf '%s\n' "${element3list[@]}"
                                        print_empty_line

                                        echo -e "Element1(Google):\t$element1"
                                        echo -e "Element1_base:\t\t$element1_base"
                                        echo -e "Remoteexif:\t\t$remoteexif"
                                        echo -e "Element3(Local):\t$element3"
                                        echo -e "Element3_base:\t\t$element3_base"
                                        echo -e "Element3 exif:\t\t$element3_exif"
                                        print_empty_line

                                        echo -e "REMOTE $i: \t exif:${onlygoogleexifarray[i]}\t${onlygoogle[i]}"
                                        echo -e "LOCAL file: \t exif:$element3_exif\t${element3list[s]}"
                                        DIR1="$(dirname "$dir${onlygoogle[i]}")"
                                        mkdir -p "$DIR1"
                                        echo "cp $dir${element3list[s]}" "$dir${onlygoogle[i]}"
                                        cp "$dir${element3list[s]}" "$dir${onlygoogle[i]}"
                                        unset "onlygoogle[i]"
                                        unset "onlygoogleexifarray[i]"
                                        willdelete+=("${element3list[s]}")
                                        echo "Adding ${element3list[s]} to delete list..."
                                        print_empty_line
                                        #break ??????????
                                        fi
                                fi
                                done
                fi
done

########## COMPARE FILES WITH KIRLANGIC 1234
onlygoogle=("${onlygoogle[@]}")
onlygoogleexifarray=("${onlygoogleexifarray[@]}")
echo "KIRLANGIC KONTROLU ONCESI"
printf '%s\n' "${onlygoogle[@]}"
printf '%s\n' "${onlygoogleexifarray[@]}"
print_empty_line/IMG_8005

#echo "CP5"
for x in "${!onlygoogle[@]}"; do
remote4="${onlygoogle[x]}"
remote4_base="$(basename "$remote4")"
remote4exif="${onlygoogleexifarray[x]}"
unset local5list
remote4_base=$(kirlangic_check "$remote4_base")

IFS=$'\n' local5list=($(find $dir -name "$remote4_base*" -type f -print | sed "s|$dir||"))
#echo "Aranan oge: $remote4_base"
#echo "Bu oge ile match eden bulduklarim"
#printf '%s\n' "${local5list[@]}"

        #echo "CP6"
        ZZ="${#local5list[@]}"
        for ((t=0; t<$ZZ; t++)); do
        local5element="${local5list[t]}"
        local5element_base="$(basename "$local5element")"
        local5element_base=$(kirlangic_check "$local5element_base")
        local5element_base=$(extension_remove "$local5element_base")
        local5elementexif=$(local_exif_date "$dir/${local5list[$t]}")

                #echo "CP7"
                if [ "$local5element_base" == "$remote4_base" ]; then
                        #echo "CP8"
                        if [ "$local5elementexif" == "$remote4exif" ]; then

                        echo "###########################################################"
                        echo "# --------> KIRLANGICCCC ...                              #"
                        echo "###########################################################"
                        print_empty_line

                        echo -e "remote4:\t\t$remote4"
                        echo -e "remote4_base:\t\t$remote4_base"
                        echo -e "remote4exif:\t\t$remote4exif"
                        echo -e "local5element:\t\t$local5element"
                        echo -e "local5element_base:\t$local5element_base"
                        echo -e "local5elementexif:\t$local5elementexif"
                        print_empty_line

                        echo -e "REMOTE $x: \t exif:$remote4exif\t$remote4\t$remote4_base"
                        echo -e "LOCAL  $t: \t exif:$local5elementexif\t$local5element\t$local5element_base"
                        DIR5="$(dirname "$dir$remote4")"
                        mkdir -p "$DIR5"
                        cp "$dir$local5element" "$dir$remote4"
                        echo "cp $dir$local5element" "$dir$remote4"
                        unset "onlygoogle[x]"
                        unset "onlygoogleexifarray[x]"
                        print_empty_line
                        fi
                fi
        done
done

### DIREKT SILINEBILIRLERI ARRAY ILE TOPLADIKTAN SONRA YENIDEN ONLYLOCAL list genereate ediliyor.
### Eger bu only local ler zaten add list te var ise direkt siliniyorlar...
### oncesinde dosya operasyonu yaptigimiz icin listeyi yeniden generate ediyoruz.
rm $fulllist_local
fulllist_local=$(mktemp)
find "$dir" -type f \( ! -name '*.swf' ! -name '*.exe' \) -print |  sed "s|$dir||" > $fulllist_local

rm $onlylocalfilestxt
onlylocalfilestxt=$(mktemp)
grep -Fxv -f "$fulllist_google" "$fulllist_local" > $onlylocalfilestxt

for x in "${!willdelete[@]}"; do
cat $onlylocalfilestxt | grep "${willdelete[x]}"
status=$?
if [ $status -eq 0 ]
then
  echo "rm $dir${willdelete[x]} executed."
  rm "$dir${willdelete[x]}"
  ##echo var
#else
  ##echo yok
fi
done

#################### CHECK WHATs REMAINING ######
onlygoogle=("${onlygoogle[@]}")
sonuzunluk="${#onlygoogle[@]}"
if [ "$sonuzunluk" == "0" ]; then
echo "TUM DOSYALAR GOOGLE ILE BASARI ILE SYNKRONIZE EDILDI..."
else
echo "DIKKKATTTTT!!!! Son durumda GOOGLE da olup operasyonu yapilamayanlar:"
echo "Google da islenemeyen dosyalar var.." >> $message
printf '%s\n' "${onlygoogle[@]}" >> $message
print_empty_line
fi

########## REGENERATE FULL LOCAL list/file to see diff
rm $fulllist_local
fulllist_local=$(mktemp)
find "$dir" -type f \( ! -name '*.swf' ! -name '*.exe' \) -print |  sed "s|$dir||" > $fulllist_local

rm $onlylocalfilestxt
#rm $onlyremotefilestxt
onlylocalfilestxt=$(mktemp)
#onlyremotefilestxt=$(mktemp)
grep -Fxv -f "$fulllist_google" "$fulllist_local" > $onlylocalfilestxt
#grep -Fxv -f "$fulllist_local" "$fulllist_google" > $onlyremotefilestxt
print_empty_line

echo "ARSIVDE TEMIZLIK YAPILIYOR.."
unset onlylocal
IFS=$'\n' onlylocal=($(cat $onlylocalfilestxt))
print_empty_line

#### MOVING to PHOTOJUNK
for i in "${!onlylocal[@]}"; do
    DIR2="$(dirname $PHOTOJUNK/${onlylocal[$i]})"
    mkdir -p "$DIR2"
    mv "$dir${onlylocal[$i]}" "$PHOTOJUNK/${onlylocal[$i]}"
    echo "$dir${onlylocal[$i]} moved to junk..."
done

#### GARBAGE CLEANING for WHOLE ARCHIEVE and JUNK FOLDER
find "$dir" -type d -empty -print -delete
find "$PHOTOJUNK" -type d -empty -print -delete

echo "Script sonunda foto sayilari:"
var1=$(cat $fulllist_google | wc -l)
var2=$(find "$dir" -type f \( ! -name '*.swf' ! -name '*.exe' \) | wc -l)
echo "Google photo count: $var1"
echo "Local  photo count: $var2"
print_empty_line

if [ "$var1" != "$var2" ]; then
echo "Script ended, R:$var1 L:$var2" >> $message
sendpushnotification "$(cat $mesaj)"
fi


echo $mesaj
echo $googlerawlist
echo $fulllist_google
echo $fulllist_google_with_exif
echo $fulllist_local
echo $onlylocalfilestxt
echo $onlyremotefilestxt
echo $exifdiff

rm $mesaj
rm $googlerawlist
rm $fulllist_google
rm $fulllist_google_with_exif
rm $fulllist_local
rm $onlylocalfilestxt
rm $onlyremotefilestxt
rm $exifdiff

cp $fulllist_google_with_exif $previous_google_with_exif


finish=$(date +%s.%N)
dt=$(echo "$finish - $start" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)


LC_NUMERIC=C printf "Total runtime of the script for this cycle: %d:%02d:%02d:%02.4f\n" $dd $dh $dm $ds
echo "Finished."

exit 0
