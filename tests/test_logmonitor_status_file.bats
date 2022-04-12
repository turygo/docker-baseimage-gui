#!/bin/env bats

setup() {
    load setup_common

    # Create logmonitor config file.
    echo "STATUS_FILES=/tmp/test1.status,/tmp/test2.status" > "$TESTS_WORKDIR"/logmonitor.conf

    # Create first notification definition.
    mkdir "$TESTS_WORKDIR"/test1
    echo 'Test1 title' > "$TESTS_WORKDIR"/test1/title
    echo 'Test description' > "$TESTS_WORKDIR"/test1/desc
    echo ERROR > "$TESTS_WORKDIR"/test1/level
    cat << EOF > "$TESTS_WORKDIR"/test1/filter
#!/bin/sh
echo RUNNING_FILTER1 on: \$1
echo "\$1" | grep -q TriggerWord
EOF
    chmod +x "$TESTS_WORKDIR"/test1/filter

    # Create second notification definition.
    mkdir "$TESTS_WORKDIR"/test2
    echo 'Test2 title' > "$TESTS_WORKDIR"/test2/title
    echo 'Test description' > "$TESTS_WORKDIR"/test2/desc
    echo ERROR > "$TESTS_WORKDIR"/test2/level
    cat << EOF > "$TESTS_WORKDIR"/test2/filter
#!/bin/sh
echo RUNNING_FILTER2 on: \$1
echo "\$1" | grep -q TriggerAnotherWord
EOF
    chmod +x "$TESTS_WORKDIR"/test2/filter

    DOCKER_EXTRA_OPTS=()
    DOCKER_EXTRA_OPTS+=("-v" "$TESTS_WORKDIR/logmonitor.conf:/etc/logmonitor/logmonitor.conf")
    DOCKER_EXTRA_OPTS+=("-v" "$TESTS_WORKDIR/test1:/etc/logmonitor/notifications.d/test1")
    DOCKER_EXTRA_OPTS+=("-v" "$TESTS_WORKDIR/test2:/etc/logmonitor/notifications.d/test2")

    load setup_container_daemon
}

teardown() {
    load teardown_container_daemon
    load teardown_common
}

@test "Checking log monitor functionality with status files..." {
    exec_container_daemon sh -c "echo TriggerWord > /tmp/test1.status"
    exec_container_daemon sh -c "echo TriggerAnotherWord > /tmp/test2.status"
    sleep 20

    # Dump docker logs before proceeding to validations.
    echo "====================================================================="
    echo " DOCKER LOGS"
    echo "====================================================================="
    getlog_container_daemon
    echo "====================================================================="
    echo " END DOCKER LOGS"
    echo "====================================================================="

    run getlog_container_daemon
    count1=0
    count2=0
    for item in "${lines[@]}"; do
        regex1=".*ERROR: Test1 title Test description"
        regex2=".*ERROR: Test2 title Test description"
        if [[ "$item" =~ $regex1 ]]; then
            count1="$(expr $count1 + 1)"
        elif [[ "$item" =~ $regex2 ]]; then
            count2="$(expr $count2 + 1)"
        fi
    done
    [ "$count1" -eq 1 ]
    [ "$count2" -eq 1 ]
}

# vim:ft=sh:ts=4:sw=4:et:sts=4
