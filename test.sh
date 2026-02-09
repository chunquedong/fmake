cd test/cppLib
fmake fmake.props -G
cd ../..

cd test/cppExe
fmake fmake.props -G
cd ../..


cd test/cppLib
fmake fmake.props -f
cd ../..

cd test/cppExe
fmake fmake.props -f
cd ../..
