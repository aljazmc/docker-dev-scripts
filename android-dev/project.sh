#!/bin/bash

## Variables

KVMOWNER=$(ls -l /dev/kvm | awk '{print $3}')
#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
SDK=$(echo /home/"$USER"/sdk)
USER=android

# if [[ "$KVMOWNER" != "$(id -u):$(id -g)" ]]; then 
#     echo "'/dev/kvm' is not owned by the current user. Aborting..."
#     exit
# fi

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

if [[ ! -f docker-compose.yml ]]; then
    cat <<-EOF > docker-compose.yml
services:
    android:
        build: .
        working_dir: /home/$USER
        user: $PROJECT_UID:$PROJECT_GID
        environment:
            DISPLAY: $DISPLAY
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

    docker compose run --rm android sh -c " \
        wget https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip \
        && unzip commandlinetools-linux-*_latest.zip cmdline-tools/* -d sdk/cmdline-tools \
        && cd sdk/cmdline-tools \
        && mv cmdline-tools latest \
        && rm ../../commandlinetools-linux-*_latest.zip \
	&& cd /home/android \
        && wget https://services.gradle.org/distributions/gradle-9.5.1-bin.zip \
        && unzip gradle-9.5.1-bin.zip -d sdk \
        && rm gradle-*-bin.zip \
        && wget https://github.com/JetBrains/kotlin/releases/download/v2.4.0/kotlin-compiler-2.4.0.zip \
        && unzip kotlin-compiler-2.4.0.zip -d sdk \
        && rm kotlin-compiler-*.zip \
        && yes | sdkmanager --licenses \
        && sdkmanager --update \
        && sdkmanager \
            'build-tools;35.0.0' \
            'cmake;4.1.2' \
            'emulator' \
            'ndk;30.0.14904198' \
            'platform-tools' \
            'platforms;android-36' \
            'system-images;android-36;default;x86_64' \
	&& sdkmanager --list \
        && cd app \
	&& yes | gradle init --type kotlin-application --dsl kotlin \
        && echo 'no' | avdmanager create avd -n 1 -k 'system-images;android-36;default;x86_64'"
  
    mate-terminal -- sh -c "docker compose run --rm android sh -c 'emulator -avd 1'"
  
    confighack
    
    docker compose run --rm android sh -c "cd app && gradlew tasks"
    docker compose run --rm android sh -c "cd app && gradlew build"
    docker compose run --rm android sh -c "cd app && gradlew installDebug"
    docker compose run --rm android sh -c "adb shell 'am start -n org.example/org.example.App'"
  
}

"$1"
