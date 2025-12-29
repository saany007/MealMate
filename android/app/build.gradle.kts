plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// FORCE STABLE DEPENDENCIES
// This block forces the app to use stable versions, ignoring the "API 36" requirement
configurations.all {
    resolutionStrategy {
        force("androidx.activity:activity:1.9.3")
        force("androidx.activity:activity-ktx:1.9.3")
    }
}

android {
    namespace = "com.example.mealmate"
    compileSdk = 36 // UPDATED: Changed from 35 to 36 to fix plugin errors
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        // NEW: Required for flutter_local_notifications to work on older Android versions
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.mealmate"
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // UPDATED: Changed from 35 to 36
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // NEW: Core Library Desugaring (Required for notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Firebase BoM 
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    
    // Firebase dependencies
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
    
    // MultiDex support
    implementation("androidx.multidex:multidex:2.0.1")

    // FORCE STABLE ACTIVITY VERSION 
    implementation("androidx.activity:activity-ktx:1.9.3")
}