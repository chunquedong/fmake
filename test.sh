cd test/cppLib
fan fmake fmake.props -G
cd ../..

cd test/cppExe
fan fmake fmake.props -G
cd ../..


cd test/cppLib
fan fmake fmake.props -f
cd ../..

cd test/cppExe
fan fmake fmake.props -f
cd ../..
