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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. audioplayers_android 5.3.0) use the Kotlin `kotlin { }`
// DSL in their build.gradle but never apply the Kotlin plugin themselves,
// relying on the surrounding build to apply it. F-Droid's build environment
// does not, which breaks evaluation ("Could not find method kotlin()").
// Force-apply the Kotlin Android plugin to every Android library subproject
// so the build no longer depends on that implicit behavior.
subprojects {
    plugins.withId("com.android.library") {
        apply(plugin = "org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
