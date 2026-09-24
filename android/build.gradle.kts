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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val configureNamespaceAndManifest = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                val currentNamespace = getNamespace.invoke(android)
                if (currentNamespace == null) {
                    val groupStr = project.group.toString()
                    val fallbackNamespace = if (groupStr.isEmpty() || groupStr == "unspecified") {
                        "com.example.${project.name.replace("-", "_").replace(".", "_")}"
                    } else {
                        "$groupStr.${project.name.replace("-", "_").replace(".", "_")}"
                    }
                    setNamespace.invoke(android, fallbackNamespace)
                    logger.quiet("Injected namespace $fallbackNamespace for project ${project.name}")
                }
            } catch (e: Exception) {
                // Ignore
            }

            try {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    var content = manifestFile.readText()
                    if (content.contains("package=")) {
                        content = content.replace(Regex("""package\s*=\s*"[^"]*""""), "")
                        manifestFile.writeText(content)
                        logger.quiet("Removed package attribute from manifest for project ${project.name}")
                    }
                }
            } catch (e: Exception) {
                // Ignore
            }

            try {
                val compileSdkVersionMethod = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                compileSdkVersionMethod.invoke(android, 34)
                logger.quiet("Forced compileSdkVersion 34 for project ${project.name}")
            } catch (e: Exception) {
                try {
                    val compileSdkVersionMethod = android.javaClass.getMethod("compileSdkVersion", String::class.java)
                    compileSdkVersionMethod.invoke(android, "android-34")
                    logger.quiet("Forced compileSdkVersion android-34 for project ${project.name}")
                } catch (e2: Exception) {
                    // Ignore
                }
            }
        }
    }
    
    if (project.state.executed) {
        configureNamespaceAndManifest()
    } else {
        project.afterEvaluate {
            configureNamespaceAndManifest()
        }
    }
}
