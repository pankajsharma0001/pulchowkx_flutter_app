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

subprojects {
    fun setNamespace() {
        if (project.name == "dash_bubble") {
            try {
                val resDir = file("${project.projectDir}/src/main/res/drawable")
                if (!resDir.exists()) resDir.mkdirs()
                val closeIcon = file("${resDir}/ic_close_bubble.xml")
                if (!closeIcon.exists()) {
                    closeIcon.writeText("""
                        <vector xmlns:android="http://schemas.android.com/apk/res/android"
                            android:width="24dp"
                            android:height="24dp"
                            android:viewportWidth="24"
                            android:viewportHeight="24">
                            <path
                                android:fillColor="#FF000000"
                                android:pathData="M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z" />
                        </vector>
                    """.trimIndent())
                }
            } catch (e: Exception) {
                logger.warn("Failed to create missing dash_bubble resource: ${e.message}")
            }

            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.let {
                if (it.namespace == null) {
                    it.namespace = "dev.moaz.dash_bubble"
                }
            }
        }
    }

    if (project.state.executed) {
        setNamespace()
    } else {
        afterEvaluate { setNamespace() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
