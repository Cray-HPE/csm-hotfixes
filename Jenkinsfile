@Library('csm-shared-library') _

pipeline {
  agent {
    node { label 'metal-gcp-builder' }
  }

  // Configuration options applicable to the entire job
  options {
    // Don't fill up the build server with unnecessary cruft
    buildDiscarder(logRotator(numToKeepStr: '15'))

    timestamps()
  }

  parameters {
    string(name: 'SLACK_CHANNEL', description: 'The slack channel to send upload results to. Empty to disable. For testing you can use csm-release-alerts', defaultValue: "casm_release_management")
  }

  environment {
    GCS_PREFIX="gs://csm-release-public/hotfix"
    GOOGLE_APPLICATION_CREDENTIALS=credentials('csm-gcp-release-gcs-admin')
    CLOUDSDK_CONFIG="${WORKSPACE}/env/gcloud"
  }

  stages {
    stage('Setup') {
      steps {
        sh '''#!/usr/bin/env bash
          # Pull release tools
          source "./vendor/stash.us.cray.com/scm/shastarelm/release/lib/release.sh"
          docker pull "$PACKAGING_TOOLS_IMAGE"
          docker pull "$RPM_TOOLS_IMAGE"
          docker pull "$SKOPEO_IMAGE"

          gcloud auth activate-service-account --key-file ${GOOGLE_APPLICATION_CREDENTIALS}
          gcloud config set core/project csm-release
          mkdir -p dist
          touch dist/build.txt
        '''
      }
    }

    stage('Find hotfixes to build') {
      steps {
        sh '''
          for HOTFIX in casmrel-* ; do
            VERSION="$([[ -f ${HOTFIX}/.version ]] && (cat ${HOTFIX}/.version |  tr -d '\n') || echo "0.0.1")"
            GCS_FILE="${GCS_PREFIX}/${HOTFIX}-${VERSION}.tar.gz"

            echo "Looking for existing distribution ${GCS_FILE}"
            if gsutil -q stat ${GCS_FILE}; then
              echo "Distribution already found for ${HOTFIX}. Not rebuilding"
              echo "https://storage.googleapis.com/csm-release-public/hotfix/${HOTFIX}-${VERSION}.tar.gz"
            else
              echo "Distribution not found for ${HOTFIX}. Building"
              echo ${HOTFIX} >> dist/build.txt
            fi
          done

          echo "Hotfixes to build"
          cat dist/build.txt
        '''
      }
    }

    stage('Build Hotfixes') {
      steps {
        sh '''
          while read HOTFIX; do
            echo "Building ${HOTFIX}"
            ./release.sh ${HOTFIX}
          done < dist/build.txt
        '''
      }
    }

    stage('Upload to GCP') {
      when {
        branch 'master'
      }
      steps {
        script {
          sh '''
            touch dist/built.txt
            while read HOTFIX; do
              VERSION="$([[ -f ${HOTFIX}/.version ]] && (cat ${HOTFIX}/.version |  tr -d '\n') || echo "0.0.1")"
              DIST_FILE="dist/${HOTFIX}-${VERSION}.tar.gz"
              GCS_FILE="${GCS_PREFIX}/${HOTFIX}-${VERSION}.tar.gz"

              echo "Uploading ${DIST_FILE} to ${GCS_FILE}"
              gsutil cp ${DIST_FILE} ${GCS_FILE}

              URL="https://storage.googleapis.com/csm-release-public/hotfix/${HOTFIX}-${VERSION}.tar.gz"
              echo "Hotfix available at"
              echo "${URL}"

              echo "${HOTFIX}-${VERSION}" >> dist/built.txt
            done < dist/build.txt
          '''

          def hotfixes = readFile("dist/built.txt").split("\n")
          for(String hotfix in hotfixes) {
            if(params.SLACK_CHANNEL != "" && hotfix != "") {
              slackSend(channel: params.SLACK_CHANNEL, color: "good", message: "Hotfix ${hotfix} Uploaded to https://storage.googleapis.com/csm-release-public/hotfix/${hotfix}.tar.gz")
            }
          }
        }
      }
    }
  }
}
