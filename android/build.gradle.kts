allprojects {
    repositories {
        google()
        mavenCentral()
        // SuperLyricApi / lyricon 等依赖托管在 JitPack
        maven { url = uri("https://jitpack.io") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ---------------------------------------------------------------------------
// CI 绕过：插件模块（如 file_selector_android）的 lintVitalAnalyzeRelease 会崩：
//   'java.lang.Object java.util.List.removeLast()' ← CommentDetector 的已知 bug
// 失败来自 lint 本身而不是代码，且 release 打包不需要 lint，故统一关闭。
// ---------------------------------------------------------------------------
subprojects {
    tasks.configureEach {
        if (name.startsWith("lint")) {
            enabled = false
        }
    }
}
