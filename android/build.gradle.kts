allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // share_plus pulls in AndroidX libs (window/fragment) that require
    // compileSdk 34+. Some plugin modules (e.g. flutter_native_splash) pin an
    // older compileSdk and break the AAR-metadata check, so force a modern
    // compileSdk on every Android subproject. Registered here — before the
    // evaluationDependsOn block below forces evaluation — and via reflection so
    // the AGP types aren't needed on the root classpath.
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                androidExt.javaClass
                    .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(androidExt, 36)
            } catch (_: Exception) {
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
