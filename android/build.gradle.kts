allprojects {
//    ext.kotlin_version = '1.9.22'
    repositories {
        google()
        mavenCentral()
    }
//    dependencies {
//        classpath 'com.android.tools.build:gradle:8.1.2'; // or latest
//        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version";
//    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
