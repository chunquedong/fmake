cd test/cppLib
fan fmake fmake.props -G
cd ../..

cd test/cppExe
fan fmake fmake.props -G
cd ../..


cd test/cppLib
fan fmake fmake.props
cd ../..

cd test/cppExe
fan fmake fmake.props
cd ../..
