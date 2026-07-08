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

// -------------------------------------------------------------------
// Force every Android library plugin to compile against compileSdk 36.
// Some plugins ship with compileSdk = 34 but their transitive deps
// require 36 (see .cursor/rules/gray_part_pitfalls.md §2). The
// afterEvaluate override MUST be registered BEFORE the eager
// `evaluationDependsOn(":app")` block below — otherwise Gradle throws
// "Project.afterEvaluate(Action) when the project is already evaluated"
// (§7).
// -------------------------------------------------------------------
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
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
