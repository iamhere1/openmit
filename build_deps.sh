#!/bin/bash -x

cd $(dirname `ls -l $0 | awk '{print $NF;}'`)
wk_dir=`pwd`
third_party_dir=$wk_dir/third_party

set -o pipefail
set -o errexit

git submodule init
git submodule update

# env config.mk
if [ "x$HADOOP_HOME" == "x" ] || [ "x$CLAPACK_HOME" == "x" ]; then
  source $wk_dir/make/config.mk
fi
export HADOOP_HOME=$HADOOP_HOME
if [ "x$HADOOP_HOME" == "x" ]; then
  echo "[WARN] HADOOP_HOME is null, dmlc-core not support hdfs compile and yarn submit!!!!!"
fi
export HADOOP_HDFS_HOME=$HADOOP_HOME
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HADOOP_HOME/lib/native
export HDFS_INC_PATH=${HADOOP_HOME}/include
export HDFS_LIB_PATH=${HADOOP_HOME}/lib/native
export CLAPACK_HOME=$CLAPACK_HOME

mkdir -p $third_party_dir/{include,lib} || true

cp -r $HADOOP_HOME/include/* $third_party_dir/hadoop/include
cp -r $HADOOP_HOME/lib/native/* $third_party_dir/hadoop/lib

#cd $third_party_dir/liblbfgs
#./autogen.sh && ./configure --prefix=$third_party_dir --disable-shared --enable-static --enable-sse2
#make && make install

echo "[INFO] build openmit/ps-lite begin ..."
cd $third_party_dir/ps-lite
make clean
#git stash || true
#git checkout master 
#git pull origin master  
make -j4 \
  && cp -r include/* $third_party_dir/include \
  && cp -r build/libps.a $third_party_dir/lib \
  && cp -r deps/lib/lib*.a $third_party_dir/lib
echo "[INFO] build openmit/ps-lite done"

cd $third_party_dir/rabit
make clean
make all \
  && cp -r include/* $third_party_dir/include \
  && cp -r lib/librabit.a $third_party_dir/lib

cd $third_party_dir/dmlc-core
make clean
make all DMLC_ENABLE_STD_THREAD=1 USE_HDFS=1 DMLC_USE_REGEX=1 USE_OPENMP=1 \
         DMLC_USE_GLOG=1 \
         HDFS_INC_PATH=$HADOOP_HOME/include HDFS_LIB_PATH=$HADOOP_HOME/lib/native \
  && cp -r include/dmlc $third_party_dir/include \
  && cp libdmlc.a $third_party_dir/lib

#cd $third_party_dir/googletest 
#make clean 
#cmake . && make \
#  && cp -r googletest/include/gtest $third_party_dir/include \
#  && cp googlemock/gtest/libgtest* $third_party_dir/lib 

cd $third_party_dir/liblbfgs
sh autogen.sh \
  && ./configure \
  && make \
  && rm -rf $third_party_dir/include/liblbfgs \
  && cp -r include $third_party_dir/include/liblbfgs \
  && cp lib/.libs/liblbfgs.a $third_party_dir/lib \
  && cp lib/.libs/liblbfgs-1.10.so $third_party_dir/lib
 

mkdir -p $third_party_dir/include/clapack
cp -r $CLAPACK_HOME/INCLUDE/* $third_party_dir/include/clapack
cp -r $CLAPACK_HOME/blas_LINUX.a $third_party_dir/lib/libblas.a
cp -r $CLAPACK_HOME/lapack_LINUX.a $third_party_dir/lib/libclapack.a


#echo "[INFO] build third_party/glog begin"
#cd $third_party_dir/glog
##automake --add-missing && ./configure \
#./configure \
#    && sed -i 's/aclocal-1.14/aclocal/g;s/automake-1.14/automake/g' Makefile \
#    && make \
#    && cp -r src/glog $third_party_dir/include \
#    && cp .libs/libglog.a $third_party_dir/lib
#echo "[INFO] build third_party/glog done"
