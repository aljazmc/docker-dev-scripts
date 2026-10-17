#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
KVM_GID=$(stat -c %g /dev/kvm 2>/dev/null)
RENDER_GID=$(stat -c %g /dev/dri/renderD* 2>/dev/null | head -n 1)
VIDEO_GID=$(stat -c %g /dev/dri/card* 2>/dev/null | head -n 1)
AUDIO_GID=$(stat -c %g /dev/snd/controlC* 2>/dev/null | head -n 1)
GROUP_ADD=$(printf '%s\n' $KVM_GID $RENDER_GID $VIDEO_GID $AUDIO_GID | sort -un | sed '/^0\?$/d; s/.*/            - "&"/')
USER=android

CMDLINE_TOOLS_VERSION=14742923
GRADLE_VERSION=9.5.1 ## keep in sync with GRADLE_HOME and PATH in Dockerfile
KOTLIN_VERSION=2.4.0
SYSTEM_IMAGE="system-images;android-36;default;x86_64"

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    docker system prune -af --volumes

    find . -mindepth 1 -maxdepth 1 \
        | sed "
            /Dockerfile/d;
            /project.sh/d;
        " \
        | xargs -I {} rm -rf {}

}

compose() {

    if [[ ! -f docker-compose.yml ]]; then
        cat << EOF > docker-compose.yml
services:
    android:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/$PROJECT_UID:/run/user/$PROJECT_UID
            - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
            - ~/.Xauthority:/home/$USER/.Xauthority
        environment:
            DISPLAY: $DISPLAY
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
        devices:
            - /dev/dri:/dev/dri
            - /dev/kvm:/dev/kvm
            - /dev/snd:/dev/snd
${GROUP_ADD:+        group_add:
$GROUP_ADD
}        network_mode: host
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

sdk() {

    if [[ ! -d sdk/cmdline-tools/latest ]]; then
        mkdir -p sdk/cmdline-tools
        docker compose run --rm android sh -c " \
            wget https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip \
            && unzip commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip 'cmdline-tools/*' -d sdk/cmdline-tools \
            && mv sdk/cmdline-tools/cmdline-tools sdk/cmdline-tools/latest \
            && rm commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip \
            && wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
            && unzip gradle-${GRADLE_VERSION}-bin.zip -d sdk \
            && rm gradle-${GRADLE_VERSION}-bin.zip \
            && wget https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip \
            && unzip kotlin-compiler-${KOTLIN_VERSION}.zip -d sdk \
            && rm kotlin-compiler-${KOTLIN_VERSION}.zip \
            && yes | sdkmanager --licenses \
            && sdkmanager --update \
            && sdkmanager \
                'build-tools;35.0.0' \
                'cmake;4.1.2' \
                'emulator' \
                'ndk;30.0.14904198' \
                'platform-tools' \
                'platforms;android-36' \
                '$SYSTEM_IMAGE' \
            && sdkmanager --list \
            && echo 'no' | avdmanager create avd -n 1 -k '$SYSTEM_IMAGE'"
    fi

}

app() {

    if [[ ! -f app/gradlew ]]; then
        mkdir -p app
        docker compose run --rm android sh -c " \
            cd app \
            && yes | gradle init --type kotlin-application --dsl kotlin"
    fi

    confighack

}

confighack() {

    mkdir -p app/app/src/main/resources/values

    if [[ ! -f app/app/src/main/AndroidManifest.xml ]]; then
        cat << EOF > app/app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="App" android:allowBackup="false">
        <activity android:name="App">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF
        {
            echo "org.gradle.configuration-cache=true"
            echo "android.useAndroidX=true"
        } >> app/gradle.properties
        cat << EOF > app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.compose.compiler) apply false
}
EOF
        cat << EOF > app/app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.compose.compiler)
}

android {
    compileSdk = 36

    defaultConfig {
        minSdk = 28
        namespace = "org.example"

        applicationId = "org.example"
        versionCode = 1
        versionName = "v1"
    }
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

dependencies {
    implementation(libs.androidx.activity)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    // Use the Kotlin Test integration.
    testImplementation("org.jetbrains.kotlin:kotlin-test")

    // Use the JUnit 5 integration.
    testImplementation(libs.junit.jupiter.engine)

    testRuntimeOnly("org.junit.platform:junit-platform-launcher")

}
EOF
        cat << "EOF" > app/settings.gradle.kts
pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = ("app")
include(":app")
EOF
        cat << EOF > app/gradle/libs.versions.toml
[versions]
activity = "1.11.0"
activity-compose = "1.11.0"
compose-material3 = "1.4.0"
agp = "8.13.1"
junit-jupiter-engine = "6.0.1"
kotlin = "2.2.21"

[libraries]
androidx-activity = { group = "androidx.activity", name = "activity", version.ref = "activity" }
androidx-activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activity-compose" }
androidx-compose-material3 = { group = "androidx.compose.material3", name = "material3", version.ref = "compose-material3" }
junit-jupiter-engine = { module = "org.junit.jupiter:junit-jupiter-engine", version.ref = "junit-jupiter-engine" }

[plugins]
compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
EOF
        cat << EOF > app/app/src/main/kotlin/org/example/App.kt
package org.example
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.Text

class App : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            Text("Hello world!")
        }
    }
}
EOF
        cat << EOF > app/app/src/test/kotlin/org/example/AppTest.kt
package org.example

import kotlin.test.Test
import kotlin.test.assertEquals

class AppTest {
    @Test fun dummyTest() {
        assertEquals(4, 2+2)
    }
}
EOF
    fi

}

android() {

    mate-terminal -- sh -c "docker compose run --rm android sh -c 'emulator -avd 1'"

    docker compose run --rm android sh -c "cd app && gradlew tasks"
    docker compose run --rm android sh -c "cd app && gradlew build"
    docker compose run --rm android sh -c "cd app && gradlew installDebug"
    docker compose run --rm android sh -c "adb shell 'am start -n org.example/org.example.App'"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    sdk
    app
    android

}

"$1"
