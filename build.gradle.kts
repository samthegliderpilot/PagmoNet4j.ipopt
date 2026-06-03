plugins {
    java
    `maven-publish`
}

group = "io.github.samthegliderpilot"
version = "1.0.0-beta.6"

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
    withSourcesJar()
    withJavadocJar()
}

repositories {
    mavenLocal()  // populated by CI: ./gradlew :core:publishToMavenLocal from PagmoNet4j checkout
    mavenCentral()
    maven {
        url = uri("https://maven.pkg.github.com/samthegliderpilot/PagmoNet4j")
        credentials {
            username = System.getenv("GITHUB_ACTOR") ?: ""
            password = System.getenv("GITHUB_TOKEN") ?: ""
        }
    }
}

sourceSets {
    main {
        java {
            srcDirs("src/generated/java")
        }
    }
}

dependencies {
    implementation("io.github.samthegliderpilot:pagmonet4j:1.0.0-beta.6")
    testImplementation(platform("org.junit:junit-bom:5.11.3"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

// SWIG-generated code has missing @param/@return tags — suppress doclint so javadoc doesn't fail.
tasks.javadoc {
    (options as StandardJavadocDocletOptions).addStringOption("Xdoclint:none", "-quiet")
}

tasks.test {
    useJUnitPlatform()
    val nativeDir = System.getenv("PAGMO4J_NATIVE_DIR")
        ?.let { rootProject.projectDir.resolve(it).absolutePath }
        ?: "."
    systemProperty("java.library.path", nativeDir)
    forkEvery = 1
    maxParallelForks = 1
    systemProperty("junit.jupiter.execution.timeout.default", "30s")
}

publishing {
    repositories {
        mavenLocal()
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/samthegliderpilot/PagmoNet4j.ipopt")
            credentials {
                username = System.getenv("GITHUB_ACTOR") ?: ""
                password = System.getenv("GITHUB_TOKEN") ?: ""
            }
        }
    }
    publications {
        create<MavenPublication>("maven") {
            artifactId = "pagmonet4j-ipopt"
            from(components["java"])
            pom {
                name.set("pagmonet4j-ipopt")
                description.set("Optional IPOPT add-on for pagmonet4j — interior-point gradient-based solver")
                url.set("https://github.com/samthegliderpilot/PagmoNet4j.ipopt")
                licenses {
                    license {
                        name.set("LGPL-2.1-or-later")
                        url.set("https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html")
                    }
                }
                developers {
                    developer {
                        id.set("samthegliderpilot")
                        name.set("samthegliderpilot")
                        email.set("samthegliderpilot@gmail.com")
                    }
                }
                scm {
                    url.set("https://github.com/samthegliderpilot/PagmoNet4j.ipopt")
                    connection.set("scm:git:git://github.com/samthegliderpilot/PagmoNet4j.ipopt.git")
                    developerConnection.set("scm:git:ssh://github.com/samthegliderpilot/PagmoNet4j.ipopt.git")
                }
                issueManagement {
                    system.set("GitHub")
                    url.set("https://github.com/samthegliderpilot/PagmoNet4j.ipopt/issues")
                }
            }
        }
    }
}
