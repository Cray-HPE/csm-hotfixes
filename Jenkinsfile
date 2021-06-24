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
          for HOTFIX in $(find . -type d -name '*-*' -maxdepth 1 | sed 's|^\\./||') ; do

            [[ -f "${HOTFIX}/lib/version.sh" ]] || continue
            source "${HOTFIX}/lib/version.sh"

            GCS_FILE="${GCS_PREFIX}/${RELEASE}.tar.gz"

            echo "Looking for existing distribution ${GCS_FILE}"
            if gsutil -q stat ${GCS_FILE}; then
              echo "Distribution already found for ${RELEASE}. Not rebuilding"
              echo "https://storage.googleapis.com/csm-release-public/hotfix/${RELEASE}.tar.gz"
            else
              echo "Distribution not found for ${RELEASE}. Building"
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
              source "${HOTFIX}/lib/version.sh"

              DIST_FILE="dist/${RELEASE}.tar.gz"
              GCS_FILE="${GCS_PREFIX}/${RELEASE}.tar.gz"

              echo "Uploading ${DIST_FILE} to ${GCS_FILE}"
              gsutil cp ${DIST_FILE} ${GCS_FILE}

              URL="https://storage.googleapis.com/csm-release-public/hotfix/${RELEASE}.tar.gz"
              echo "Hotfix available at"
              echo "${URL}"

              echo "Hotfix ${RELEASE} uploaded to ${URL}" >> dist/slack.txt
            done < dist/build.txt
          '''

          def msgs = readFile("dist/slack.txt").split("\n")
          for(String msg in msgs) {
            if(params.SLACK_CHANNEL != "" && msg != "") {
              slackSend(channel: params.SLACK_CHANNEL, color: "good", message: msg)
            }
          }
        }
      }
    }
  }
}
