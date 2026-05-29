allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.arthenica" && requested.name.startsWith("ffmpeg-kit-")) {
                if (requested.version == "5.1") {
                    useVersion("5.1.LTS")
                }
            }
        }
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

subprojects {
    val configureAction = Action<Project> {
        val project = this
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val namespaceProp = androidExt::class.java.getMethod("getNamespace").invoke(androidExt)
                if (namespaceProp == null) {
                    var groupStr = project.group.toString()
                    if (groupStr.isEmpty() || groupStr == "unspecified") {
                        groupStr = "com.flutter.plugin.${project.name}"
                    }
                    androidExt::class.java.getMethod("setNamespace", String::class.java).invoke(androidExt, groupStr)
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
    if (project.state.executed) {
        configureAction.execute(this)
    } else {
        project.afterEvaluate(configureAction)
    }
}
