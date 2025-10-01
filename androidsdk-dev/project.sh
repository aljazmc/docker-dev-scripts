#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
SDK=$(echo /home/"$USER"/sdk)

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
    sdk \
    .temp \
    .wget-hsts \
    ./*.zip

}

confighack() {
if [[ ! -f app/app/src/main/AndroidManifest.xml ]]; then
  cat <<EOF > app/app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <application
        android:allowBackup="true"
        android:supportsRtl="true"
        tools:targetApi="36">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />

                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
EOF
  { echo "android.useAndroidX=true"; echo "kotlin.code.style=official"; } >> app/gradle.properties
  cat <<EOF > app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
}
EOF
  cat <<EOF > app/app/build.gradle.kts
plugins {
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.android.application)
}

android {
    extra.set("appId", "org.example.app")
    namespace = "org.example.app"
    
    lint {
        abortOnError = false
    }
    
    defaultConfig {
        applicationId = "org.example.app"
        minSdk = 28
        compileSdk = 36
        targetSdk = 36
        versionCode = 1
        versionName = "v1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    
    buildTypes {
        getByName("debug") {
            isDebuggable = true
        }
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

}

kotlin {
    jvmToolchain(21)
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

dependencies {
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation(libs.junit.jupiter.engine)
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.named<Test>("test") {
    // Use JUnit Platform for unit tests.
    useJUnitPlatform()
}
EOF
  cat <<"EOF" > app/settings.gradle.kts
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "HelloWorld"
include(":app")
EOF
  cat <<EOF > app/gradle/libs.versions.toml
[versions]
agp = "8.13.0"
guava = "33.5.0-android"
kotlin = "2.2.20"
junit-jupiter-engine = "5.12.1"

[libraries]
guava = { module = "com.google.guava:guava", version.ref = "guava" }
junit-jupiter-engine = { module = "org.junit.jupiter:junit-jupiter-engine", version.ref = "junit-jupiter-engine" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
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
      GRADLE_HOME: $SDK/gradle-9.1.0/bin
      GRADLE_USER_HOME: /home/$USER/.gradle
      PATH: "/home/$USER/app:$SDK/build-tools/36.1.0:$SDK/gradle-9.1.0/bin:$SDK/kotlinc/bin:$SDK/emulator:$SDK/cmdline-tools/latest/bin:$SDK/platform-tools:\$PATH"
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
  docker compose run --rm androidsdk sh -c "wget https://services.gradle.org/distributions/gradle-9.1.0-bin.zip && \
    unzip gradle-9.1.0-bin.zip -d sdk && \
    rm gradle-*-bin.zip"
  docker compose run --rm androidsdk sh -c "wget https://github.com/JetBrains/kotlin/releases/download/v2.2.20/kotlin-compiler-2.2.20.zip && \
    unzip kotlin-compiler-2.2.20.zip -d sdk && \
    rm kotlin-compiler-*.zip"
  docker compose run --rm androidsdk sh -c "yes | sdkmanager --licenses"
  docker compose run --rm androidsdk sh -c "sdkmanager --update && \
    sdkmanager \
      'build-tools;36.1.0' \
      'cmake;4.1.1' \
      'emulator' \
      'ndk;28.2.13676358' \
      'platform-tools' \
      'platforms;android-36.1' \
      'system-images;android-36.1;google_apis;x86_64' "
  docker compose run --rm androidsdk sh -c "sdkmanager --list"
  docker compose run --rm androidsdk sh -c "printenv"
  
  docker compose run --rm androidsdk sh -c "cd app && yes | gradle init --type kotlin-application --dsl kotlin"
  docker compose run --rm androidsdk sh -c "echo 'no' | avdmanager create avd -n 1 -k 'system-images;android-36.1;google_apis;x86_64'"

#  confighack
  
  docker compose run --rm androidsdk sh -c "cd app && gradlew tasks"
}

"$1"
