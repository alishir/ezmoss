#!/usr/bin/env bash
dict=$2
lang=$1

mkdir $dict/repo
mkdir $dict/tmp
find "$dict" -mindepth 1 -maxdepth 1 -type f -print | while read fn
do
	f=`echo $fn | awk -F'/' '{print $NF}'`
	mkdir $dict/repo/$f

	if file $dict/$f | grep Zip; then
		unzip -d $dict/repo/$f $dict/$f	
	elif file $dict/$f | grep RAR; then
		unrar e -y $dict/$f $dict/repo/$f
	elif file $dict/$f | grep gzip; then
		tar xf $dict/$f  -C $dict/repo/$f
	fi
#	find $dict/tmp -name "*.m" -exec mv "{}" $dict/repo/"$f_"{}"" \;
	
	echo "file: $f"
	find "$dict/repo/$f" -type f -iname "*.m" -print | while read m
	do
		fname=`echo $m | awk -F'/' '{print $NF}'`
		echo "fname: $fname";
		newName=$f-$fname
		echo "newName: $newName";
		if [ -e  "$dict/repo/$f/$newName" ];then
			newName=$f-$RANDOM-$fname
		fi
		mv "$m" "$dict/repo/$f/$newName"
	done
	find "$dict/repo/$f/" -type d -mindepth 1 -exec rm -drf "{}" \;
	rm -drf $dict/tmp/*
 
done

# remove apple backups
find $dict/repo/ -name "*.m" -exec file {} \; | grep Apple | cut -d":" -f 1 | xargs rm -drf

./moss.pl -l $lang -d $dict/repo/*/*.m
