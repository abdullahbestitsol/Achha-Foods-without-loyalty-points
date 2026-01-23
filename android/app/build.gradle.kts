plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.achhafoods.achhafoods"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.achhafoods.achhafoods"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
//        manifestPlaceholders["appAuthRedirectScheme"] = "shop.69603295509.app"
        manifestPlaceholders["appAuthRedirectScheme"] = "dummy.callback"
    }

    signingConfigs {
        create("release") {
            storeFile = file("D:/Office Data/upload-keystore.jks")
            storePassword = "12345678"
            keyAlias = "upload"
            keyPassword = "12345678"
        }
    }

    buildTypes {
        getByName("release") {
            // This is the most important line for Play Store
            signingConfig = signingConfigs.getByName("release")

            // Play Store likes these to be 'true' to make the app smaller,
            // but set both to 'false' if you want to avoid errors for now.
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
