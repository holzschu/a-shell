#! /bin/sh

PRODUCT_BUNDLE_IDENTIFIER=Nicolas-Holzschuch
APP=$(basename $PWD)

duplicate_framework () {
	FullLocation=$1  # Frameworks/Python-regex._regex.framework or Frameworks/Python.framework
	Interpreter=$2   # PythonA

	# The name of the framework itself
	Basename=$(basename "$FullLocation")				# Python-regex._regex.framework or Python.framework
	Libraryname=$(basename -s ".framework" $Basename)	# Python-regex._regex or Python 
	if [ $Libraryname == "Python" ]; 
	then
		Interpreter=$(echo $Interpreter | sed s/Python/python/)
		# add A, B, C, D, E...
		NewFullname=$(echo $FullLocation | sed s/Python/$Interpreter/)    # Frameworks/pythonA.framework
		NewLibraryname=$Interpreter # PythonA
		cp -r $FullLocation $NewFullname # cp -r Frameworks/Python.framework Frameworks/PythonA.framework
		mv $NewFullname/$Libraryname $NewFullname/$NewLibraryname # mv Frameworks/PythonA.framework/Python Frameworks/pythonA.framework/PythonA
		plutil -replace CFBundleExecutable -string "$Interpreter" "$NewFullname/Info.plist"
		NewBundleID=$(echo $PRODUCT_BUNDLE_IDENTIFIER.$Interpreter | tr "_" "-" | sed "s/^\.//")
		plutil -replace CFBundleIdentifier -string "$NewBundleID" "$NewFullname/Info.plist"
		# Mine:
		plutil -replace CFBundleName -string $Interpreter "$NewFullname/Info.plist"
		# change framework id:
		install_name_tool -id @rpath/$Interpreter.framework/$Interpreter "$NewFullname/$NewLibraryname"
	else
		# replace "-" with A, B, C, D, E...
		Newname=$(echo $Basename | tr "Python-" $Interpreter)            # PythonAregex._regex.framework
		NewFullname=$(echo $FullLocation | tr "Python-" $Interpreter)    # Frameworks/PythonAregex._regex.framework
		NewLibraryname=$(echo $Libraryname | tr "Python-" $Interpreter)  # PythonAregex._regex
		# 
		cp -r $FullLocation $NewFullname
		mv $NewFullname/$Libraryname $NewFullname/$NewLibraryname
		mv $NewFullname/$Libraryname.origin $NewFullname/$NewLibraryname.origin
		# 
		NewBundleID=$(echo $PRODUCT_BUNDLE_IDENTIFIER.$NewLibraryname | tr "_" "-" | sed "s/^\.//")
		plutil -replace CFBundleExecutable -string "$NewLibraryname" "$NewFullname/Info.plist"
		plutil -replace CFBundleIdentifier -string "$NewBundleID" "$NewFullname/Info.plist"
		# Mine:
		plutil -replace CFBundleName -string $NewLibraryname "$NewFullname/Info.plist"
		# change framework id:
		install_name_tool -id @rpath/$NewLibraryname.framework/$NewLibraryname "$NewFullname/$NewLibraryname"
		# change Python framework:
		Interpreter=$(echo $Interpreter | sed s/Python/python/)
		install_name_tool -change "@rpath/Python.framework/Python" @rpath/${Interpreter}.framework/${Interpreter}  "$NewFullname/$NewLibraryname"
	fi
}


echo copying Library \(twice\)
rm -rf Resources/Library
# Full Python (with scipy, sklearn...)
cp -r cpython/Library Resources/Library
# Use this line if you want a smaller Python (without scipy):
# cp -r cpython/install_regular/Library Resources/Library
rm -rf Resources_mini/Library
cp -r cpython/install_mini/Library Resources_mini/Library

echo cleaning up:

for directory in Resources/Library Resources_mini/Library 
do
	find $directory -name __pycache__ -exec rm -rf {} \;
	find $directory -name \*.a -delete
	find $directory -name \*.dylib -delete
	find $directory -name \*.so -delete
	find $directory -name \.\* -delete
	# Also remove MS Windows executables:
	find $directory -name \*.exe -delete
	find $directory -name \*.dll -delete
	# remove x86_64 executables:
	rm $directory/bin/maturin
	rm $directory/bin/python3
	rm $directory/bin/python3.13
	# remove the cbc executable:
	find $directory -type f -name cbc -delete
	# Create fake binaries for pip
	touch $directory/bin/python3
	touch $directory/bin/python3.13
	# change direct_url.json files to have a more meaningful URL:
	find $directory -type f -name direct_url.json -exec sed -i bak  "s/file:.*packages/${APP}/g" {} \; -print
	find $directory -type f -name direct_url.jsonbak -delete
	# Change the supported platform so "pip check" accepts it:
	for wheelFile in `find $directory -type f -name WHEEL` 
	do
		# This needs to be ios_14_0_arm64 ... on iOS 26 devices, and ios_14_arm64 on iOS 16.
		# It has to be the result of distutils.util.get_platform() (see https://peps.python.org/pep-0425/ )
		# The call to awk makes sure the file ends with a newline
		# The first call to sed duplicates the line with -macosx_* and replaces macosx with ios_14_0_, 
		# the second line replaces the -macosx_* with ios_14_
		awk 1 $wheelFile > /tmp/ensureNewLine
		mv /tmp/ensureNewLine $wheelFile
		sed -i bak "/-macosx.*/{p;s//-ios_14_0_arm64_iphoneos/;}" $wheelFile
		sed -i bak "s/-macosx.*/-ios_14_arm64_iphoneos/g" $wheelFile
	done
	find $directory -type f -name WHEELbak -delete
	# File that contains the itms-service URL (forbidden):
	rm $directory/lib/python3.13/test/test_urlparse.py.orig
done
# Let's save 31 MB of the mini size:
rm -rf Resources_mini/Library/lib/python3.13/test/*
# Make sure this one is present:
cp Resources/Library/lib/python3.13/_sysconfigdata__ios_arm64-iphoneos.py Resources_mini/Library/lib/python3.13/

echo Copying the Frameworks
rm -rf Resources/Frameworks
cp -r cpython/iOS/Frameworks Resources/
cp -r cpython/iOS/Frameworks/arm64-iphoneos/Python.framework Resources/Frameworks
# Use this one if you want the smaller Python:
# cp -r cpython/install_regular/iOS/Frameworks Resources_regular/
rm -rf Resources_mini/Frameworks
cp -r cpython/install_mini/iOS/Frameworks Resources_mini/

echo Creating the other Frameworks
for directory in Resources Resources_mini
do
	pushd $directory
	find "Frameworks" -type d -name "*.framework" | while read FULL_EXT; do
	duplicate_framework $FULL_EXT PythonA
	# uncomment as needed:
	# duplicate_framework $FULL_EXT PythonB
	# duplicate_framework $FULL_EXT PythonC
	# duplicate_framework $FULL_EXT PythonD
	# duplicate_framework $FULL_EXT PythonE
    done
    popd
done

echo Separating the Jupyter files
mkdir -p Resources/Jupyter
rm -rf Resources/Jupyter/*
mkdir -p Resources/Jupyter/bin
mv Resources/Library/bin/jupyter* Resources/Jupyter/bin/
mv Resources/Library/etc  Resources/Jupyter/
mkdir -p Resources/Jupyter/share
mv Resources/Library/share/applications Resources/Jupyter/share
mv Resources/Library/share/icons Resources/Jupyter/share
mv Resources/Library/share/jupyter Resources/Jupyter/share
mkdir -p Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/jupyter* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/nbclassic* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/notebook* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/nbconvert* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/nbformat* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/nbclient* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/ipykernel* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/qtconsole* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/ipywidgets* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/ipympl* Resources/Jupyter/lib/python3.13/site-packages
mv Resources/Library/lib/python3.13/site-packages/ipysheet* Resources/Jupyter/lib/python3.13/site-packages
pushd Resources/Jupyter/
tar czf Jupyter.tar.gz bin share etc lib 
popd
# Create the fake commands:
for command in `ls Resources/Jupyter/bin`
do
	com=`basename $command`
	cat > Resources/Library/bin/$com << EOF
#! /bin/sh
echo 'In order to run Jupyter, you need to install the extra files with "pkg install jupyter" (approx. 330 MB)'
EOF
done




