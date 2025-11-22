#!/bin/bash

## Variables

KVMOWNER=$(ls -l /dev/kvm | awk '{print $3}');
#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
SDK=$(echo /home/"$USER"/sdk)

if [[ "$KVMOWNER" != "$USER" ]]; then 
    echo "'/dev/kvm' is not owned by the current user. Aborting..."
    exit
fi

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    docker system prune -af --volumes
    rm -rf \
        .android \
        app \
        .cache \
        .config \
        docker-compose.yml \
        Dockerfile \
        .emulator_console_auth_token \
        .gradle \
        .knownPackages \
        .kotlin \
        .pki \
        sdk \
        .temp \
        .wget-hsts \
        ./*.zip

}

confighack() {

    mkdir -p app/app/src/main/resources/values
  
    if [[ ! -f app/app/src/main/AndroidManifest.xml ]]; then
    cat <<EOF > app/app/src/main/AndroidManifest.xml
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
        echo "org.gradle.configuration-cache=true"; \
        echo "android.useAndroidX=true"; \
    } >> app/gradle.properties
    cat <<EOF > app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.compose.compiler) apply false
}
EOF
    cat <<EOF > app/app/build.gradle.kts
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
    cat <<"EOF" > app/settings.gradle.kts
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
    cat <<EOF > app/gradle/libs.versions.toml
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
    cat <<EOF > app/app/src/main/kotlin/org/example/App.kt
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
    cat <<EOF > app/app/src/test/kotlin/org/example/AppTest.kt
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

start() {

    mkdir -p app sdk/cmdline-tools

if [[ ! -f Dockerfile ]]; then
    cat <<EOF > Dockerfile
FROM debian:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    android-udev-rules \
    ca-certificates \
    default-jdk \
    libpulse-dev \
    libxcb-cursor-dev \
    libxkbfile-dev \
    libfontconfig1-dev \
    libfreetype-dev \
    libgtk-3-dev \
    libx11-dev \
    libx11-xcb-dev \
    libxcb-cursor-dev \
    libxcb-glx0-dev \
    libxcb-icccm4-dev \
    libxcb-image0-dev \
    libxcb-keysyms1-dev \
    libxcb-randr0-dev \
    libxcb-render-util0-dev \
    libxcb-shape0-dev \
    libxcb-shm0-dev \
    libxcb-sync-dev \
    libxcb-util-dev \
    libxcb-xfixes0-dev \
    libxcb-xkb-dev \
    libxcb1-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxrender-dev \
    qemu-system-x86 \
    sudo \
    udev \
    unzip \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g $PROJECT_GID -r $USER
RUN useradd -u $PROJECT_UID -g $PROJECT_GID --create-home -r $USER

#Change password
RUN echo "$USER:$USER" | chpasswd
#Make sudo passwordless
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
RUN usermod -aG sudo $USER
RUN usermod -aG kvm $USER

USER $USER
WORKDIR /home/$USER

CMD ["/bin/bash"]
EOF
fi

if [[ ! -f docker-compose.yml ]]; then
    cat <<-EOF > docker-compose.yml
services:
    androidsdk:
        build: .
        working_dir: /home/$USER
        user: $PROJECT_UID:$PROJECT_GID
        environment:
            ANDROID_HOME: $SDK
            ANDROID_USER_HOME: /home/$USER/.android
            ANDROID_SDK_ROOT: $SDK
            DISPLAY: $DISPLAY
            GRADLE_HOME: $SDK/gradle-9.2.1/bin
            GRADLE_USER_HOME: /home/$USER/.gradle
            PATH: "/home/$USER/app:$SDK/build-tools/35.0.0:$SDK/gradle-9.2.1/bin:$SDK/kotlinc/bin:$SDK/emulator:$SDK/cmdline-tools/latest/bin:$SDK/platform-tools:\$PATH"
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
            - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
            - ~/.Xauthority:/root/.Xauthority
        devices:
            - /dev/dri:/dev/dri
            - /dev/kvm:/dev/kvm
            - /dev/snd:/dev/snd
        network_mode: host
EOF
fi

    docker compose run --rm androidsdk sh -c "wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip && \
        unzip commandlinetools-linux-*_latest.zip cmdline-tools/* -d sdk/cmdline-tools && \
        cd sdk/cmdline-tools && \
        mv cmdline-tools latest && \
        rm ../../commandlinetools-linux-*_latest.zip"
    docker compose run --rm androidsdk sh -c "wget https://services.gradle.org/distributions/gradle-9.2.1-bin.zip && \
        unzip gradle-9.2.1-bin.zip -d sdk && \
        rm gradle-*-bin.zip"
    docker compose run --rm androidsdk sh -c "wget https://github.com/JetBrains/kotlin/releases/download/v2.2.21/kotlin-compiler-2.2.21.zip && \
        unzip kotlin-compiler-2.2.21.zip -d sdk && \
        rm kotlin-compiler-*.zip"
    docker compose run --rm androidsdk sh -c "yes | sdkmanager --licenses"
    docker compose run --rm androidsdk sh -c "sdkmanager --update && \
        sdkmanager \
            'build-tools;35.0.0' \
            'cmake;4.1.2' \
            'emulator' \
            'ndk;29.0.14206865' \
            'platform-tools' \
            'platforms;android-36' \
            'system-images;android-36;google_apis;x86_64' "
    docker compose run --rm androidsdk sh -c "sdkmanager --list"
    docker compose run --rm androidsdk sh -c "printenv"
    
    docker compose run --rm androidsdk sh -c "cd app && yes | gradle init --type kotlin-application --dsl kotlin"
    docker compose run --rm androidsdk sh -c "echo 'no' | avdmanager create avd -n 1 -k 'system-images;android-36;google_apis;x86_64'"
  
    mate-terminal -- sh -c "docker compose run --rm androidsdk sh -c 'emulator -avd 1'"
  
    confighack
    
    docker compose run --rm androidsdk sh -c "cd app && gradlew tasks"
    docker compose run --rm androidsdk sh -c "cd app && gradlew build"
    docker compose run --rm androidsdk sh -c "cd app && gradlew installDebug"
    docker compose run --rm androidsdk sh -c "adb shell 'am start -n org.example/org.example.App'"
  
}

"$1"
