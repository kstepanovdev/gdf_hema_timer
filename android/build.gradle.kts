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
// Apply the Kotlin Android plugin on their behalf -- but skip the subprojects
// that put their own kotlin-gradle-plugin on the buildscript classpath (e.g.
// device_info_plus). Those apply `kotlin-android` themselves at a different
// version, so applying it here too loads KGP twice from two classloaders, and
// the module's Kotlin classes then never reach the jar :app compiles against
// ("cannot find symbol: class DeviceInfoPlusPlugin").
subprojects {
    plugins.withId("com.android.library") {
        val bringsOwnKotlinPlugin =
            buildscript.configurations
                .getByName("classpath")
                .allDependencies
                .any { it.group == "org.jetbrains.kotlin" && it.name == "kotlin-gradle-plugin" }
        if (!bringsOwnKotlinPlugin) {
            apply(plugin = "org.jetbrains.kotlin.android")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
