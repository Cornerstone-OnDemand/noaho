# WARNING WRITES TO /usr/local/{lib,bin}. This is admittedly a bit of a mess,
#   I've forgotten how it all works, but, it does (2015-07-04).
# Requires (Ubuntu packages) python2-dev, python3-dev, virtualenv, virtualenvwrapper
#
# Typically, cp the source somewhere else for safety, then run this as:
#   . test-all-configurations.bash
# '. test-...' because 'workon' is a bash function (from virtualenvwrapper)
# and won't propagate into a new shell.


# YOUR WORK DIRECTORY
ROOT_DIR=$(pwd)
SRC_DIR=${ROOT_DIR}/src
# noaho.cpp is the python wrapper that Cython generates
NOAHO_WRAPPER=${SRC_DIR}/noaho.cpp
LOGFILE=${ROOT_DIR}/test-results.log
VERSIONED_CYTHON="Cython-0.29.26"
VIRTUAL_ENV_NAME="noaho-test-venv"


log () {
    msg="$1"
    echo "$CONFIG: $msg"
    echo "$CONFIG: $msg" >> $LOGFILE 2>&1
}


install_cython () {
    # I believe we start life within the venv
    py="$1"
    log "installing Cython ${VERSIONED_CYTHON}"
    cd ${ROOT_DIR}
    # remove any previous cython working/build directory
    rm -rf ${VERSIONED_CYTHON}
    # We probably moved outside of the venv, is why this installs into
    #   /usr/local/*. To fix, we should probably 'reach out to' the
    #   ${ROOT_DIR}/cython tarball, staying within the venv, and not
    #   cd out to where it is, so that it will install within the venv.
    # Expects a Cython tarball in $ROOT_DIR
    tar zxvf ${VERSIONED_CYTHON}.tar.gz || { echo "no Cython tarball" $LOGFILE 2>&1; return 1; }
    cd ${VERSIONED_CYTHON}
    ${py} setup.py install || { echo "Cython installation failed" $LOGFILE 2>&1; return 1; }
    cd ${ROOT_DIR}
    rm -rf $VERSIONED_CYTHON
    log "Have cython"
}


cython_noaho () {
    log "Cythoning noaho"
    py="$1"
    cd ${ROOT_DIR}
    clean_build_and_wrapper
    if [[ -e $NOAHO_WRAPPER ]]
    then
        log "Oook; failed to get rid of $NOAHO_WRAPPER"
    fi
    log "expect wrapper $NOAHO_WRAPPER to be absent..."
    log $(ls $NOAHO_WRAPPER)
    ${py} ${ROOT_DIR}/cython-regenerate-noaho-setup.py build_ext --inplace || { echo "regeneration failed" $LOGFILE 2>&1 ; return 1; }
    # I don't know how to get Cython to redirect its output, and it's
    # cleanest for the end user if noaho.cpp is in src

    # The noaho.cpp files are the same whether generated by python2 or python3
    #    cp ${SRC_DIR}/noaho.cpp ~/noaho.cpp.${py}
    # also makes the .so, but, let the /user/ level installation make it;
    # so get rid of this one.
    # Shouldn't I get rid of the python3 version, as well?
    clean_build
    if [[ ! -e $NOAHO_WRAPPER ]]
    then
        log "Failed to generate $NOAHO_WRAPPER"
    else
        log "expect wrapper $NOAHO_WRAPPER to be present..."
        log $(ls $NOAHO_WRAPPER)
    fi
    clean_build
}


setup_install_noaho () {
    log "setup installing noaho"
    py="$1"
    ${py} setup.py install || { echo "noaho installation failed" $LOGFILE 2>&1; return 1; }
}


test_noaho () {
    py="$1"
    log "testing noaho..."
    ${py} ${ROOT_DIR}/test-noaho.py >> ${LOGFILE} 2>&1 || { echo "noaho test failed" $LOGFILE 2>&1 ; return 1; }
    log "Done testing noaho"
}

clean_build () {
    log "clean build:"
    log "rm -rf ${ROOT_DIR}/build"
    # not just 'noaho.so' - python3's version is eg 'noaho.cpython-33m.so'
    rm -rf ${ROOT_DIR}/build
    log "rm -rf ${ROOT_DIR}/*.so"
    rm -rf ${ROOT_DIR}/*.so
}

clean_build_and_wrapper () {
    log "clean all, build and wrapper"
    clean_build
    log "clean wrapper: rm -f ${NOAHO_WRAPPER}"
    rm -f ${NOAHO_WRAPPER}
}


clean_build_and_wrapper
# clean test log
rm -f ${LOGFILE}

# Don't give these pythons' full paths - in the beginning they refer to
# the system python, later to the virtualenv version.
for py in "python2" "python3"
do
    log "" # for some reason \n doesn't work
    log "testing noaho under $py"
    mkvirtualenv --python=${py} $VIRTUAL_ENV_NAME
    log "making venv $VIRTUAL_ENV_NAME"
    cd ${ROOT_DIR}
    CONFIG=$VIRTUAL_ENV_NAME
    # virtualenvwrapper
    log "workon $CONFIG"
    workon $CONFIG
    clean_build_and_wrapper
    install_cython ${py}
    # We must use the 'target' python, because the process imports a Cython module
    cython_noaho ${py}
    cd ${ROOT_DIR}
    setup_install_noaho ${py}
    test_noaho ${py}
    #read -p "Done $CONFIG" yn
    clean_build
    # virtualenvwrapper
    log "deactivate"
    deactivate
    log "rmvirtualenv $VIRTUAL_ENV_NAME"
    rmvirtualenv $VIRTUAL_ENV_NAME
    log "removed venv $VIRTUAL_ENV_NAME"
done


on_exit () {
    log "SCRIPT FAILURE"
}

# trap errors
trap on_exit EXIT

cat ${ROOT_DIR}/test-results.log
cd ${ROOT_DIR}
