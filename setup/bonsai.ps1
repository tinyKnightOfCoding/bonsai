    [cmdletbinding()]
    param(
        [Parameter()]
        [ValidateSet("setupMain", "setupDev", "setupTest", "setupProd")]
        [string[]]$phase = @("setupMain"),
        [Parameter()]
        [ValidateSet("setupMain", "setupDev", "setupTest", "setupProd")]
        [string[]]$skip = @()
    )

    end {
        $ErrorActionPreference = "Stop"
        $defaultForeground = $host.ui.RawUI.ForegroundColor

        $PROJECT_ID_PREFIX = Read-Host "Enter project id prefix (default is randomized)"
        if (-not($PROJECT_ID_PREFIX))
        {
            $PROJECT_ID_PREFIX = -join ((97..122) | Get-Random -Count 10 | % { [char]$_ })
            Write-Output "Project ID prefix is ${PROJECT_ID_PREFIX}"
        }

        $PROJECT_NAME_PREFIX = Read-Host "Enter project name prefix"
        Write-Output "Project name prefix is ${PROJECT_NAME_PREFIX}"

        $BILLING_ACCOUNT_ID = Read-Host "Enter gcp billing account id"

        $DEFAULT_REGION = Read-Host "Enter default region (default is europe-west6)"
        if (-not($DEFAULT_REGION))
        {
            $DEFAULT_REGION = "europe-west6"
        }

        $DEFAULT_ZONE = Read-Host "Enter default zone (default is europe-west6-b)"
        if (-not($DEFAULT_ZONE))
        {
            $DEFAULT_ZONE = "europe-west6-b"
        }

        $GITHUB_REPO_OWNER = Read-Host "Enter github owner (case sensitive)"

        $GITHUB_REPO_NAME = Read-Host "Enter github name (case sensitive)"

        $PROJECT_ID_MAIN = "${PROJECT_ID_PREFIX}-main"
        $PROJECT_NAME_MAIN = "${PROJECT_NAME_PREFIX} MAIN"
        $TERRAFORM_BUCKET_NAME = "${PROJECT_ID_PREFIX}-terraform-state"
        $LOG_BUCKET_NAME = "${PROJECT_ID_PREFIX}-build-logs"
        $SA_BUILD_DEV = "bonsai-build-dev-sa"
        $SA_BUILD_DEV_EMAIL = "${SA_BUILD_DEV}@${PROJECT_ID_MAIN}.iam.gserviceaccount.com"
        $ARTIFACT_REPO_NAME = "${PROJECT_ID_PREFIX}-repo"
        $PROJECT_ID_DEV = "${PROJECT_ID_PREFIX}-dev"
        $PROJECT_NAME_DEV = "${PROJECT_NAME_PREFIX} DEV"

        if ($phase -contains "setupMain" -and -not($skip -contains "setupMain"))
        {
            $host.ui.RawUI.ForegroundColor = 'DarkGreen'
            Write-Output "[setupMain] Creating main project"
            $host.ui.RawUI.ForegroundColor = $defaultForeground

            gcloud projects create "${PROJECT_ID_MAIN}" `
            --name "${PROJECT_NAME_MAIN}"

            gcloud beta billing projects link "${PROJECT_ID_MAIN}" `
            --billing-account "$BILLING_ACCOUNT_ID"

            gcloud services enable `
            cloudbuild.googleapis.com `
            artifactregistry.googleapis.com `
            iam.googleapis.com `
            --project "${PROJECT_ID_MAIN}"

            Start-Sleep -Seconds 30

            $host.ui.RawUI.ForegroundColor = 'DarkGreen'
            Write-Output "[setupMain] Creating buckets"
            $host.ui.RawUI.ForegroundColor = $defaultForeground

            gsutil mb `
            -l "$DEFAULT_REGION" `
            --pap enforced `
            -p "${PROJECT_ID_MAIN}" `
            gs://"${TERRAFORM_BUCKET_NAME}"

            gsutil versioning set on gs://"${TERRAFORM_BUCKET_NAME}"

            gsutil mb `
            -l "$DEFAULT_REGION" `
            --pap enforced `
            -p "${PROJECT_ID_MAIN}" `
            gs://"${LOG_BUCKET_NAME}"

            $host.ui.RawUI.ForegroundColor = 'DarkGreen'
            Write-Output "[setupMain] Creating artifact repo"
            $host.ui.RawUI.ForegroundColor = $defaultForeground

            gcloud artifacts repositories create "${ARTIFACT_REPO_NAME}" `
            --repository-format docker `
            --location "${DEFAULT_REGION}" `
            --description "Docker repo" `
            --project "${PROJECT_ID_MAIN}"

            Read-Host "Please link the specified repo with your google cloud project"
        }
        if ($phase -contains "setupDev" -and -not($skip -contains "setupDev"))
        {

            $HOST_DEV = Read-Host "Enter domain for dev"

            $host.ui.RawUI.ForegroundColor = 'DarkGreen'
            Write-Output "[setupDev] Creating dev project"
            $host.ui.RawUI.ForegroundColor = $defaultForeground

            gcloud projects create "${PROJECT_ID_DEV}" `
            --name "${PROJECT_NAME_DEV}"

            gcloud beta billing projects link "${PROJECT_ID_DEV}" `
            --billing-account "$BILLING_ACCOUNT_ID"

            gcloud services enable `
            cloudresourcemanager.googleapis.com `
            compute.googleapis.com `
            iam.googleapis.com `
            --project "${PROJECT_ID_DEV}"

            Start-Sleep -Seconds 30

            gcloud iam service-accounts create "${SA_BUILD_DEV}" `
            --description "Build SA for dev" `
            --display-name "Build SA DEV" `
            --project "${PROJECT_ID_MAIN}"

            gcloud projects add-iam-policy-binding "${PROJECT_ID_MAIN}" `
            --member "serviceAccount:${SA_BUILD_DEV_EMAIL}" `
            --role roles/cloudbuild.builds.builder `
            --project "${PROJECT_ID_MAIN}"

            gcloud projects add-iam-policy-binding "${PROJECT_ID_DEV}" `
            --member "serviceAccount:${SA_BUILD_DEV_EMAIL}" `
            --role roles/editor `
            --project "${PROJECT_ID_DEV}"

            gcloud projects add-iam-policy-binding "${PROJECT_ID_DEV}" `
            --member "serviceAccount:${SA_BUILD_DEV_EMAIL}" `
            --role roles/iam.securityAdmin `
            --project "${PROJECT_ID_DEV}"

            $SA_CLOUD_RUN_DEV_EMAIL = "service-$(gcloud projects describe "${PROJECT_ID_DEV}" `
            --format 'value(projectNumber)')@serverless-robot-prod.iam.gserviceaccount.com"

            gcloud artifacts repositories add-iam-policy-binding "${ARTIFACT_REPO_NAME}" `
            --location "${DEFAULT_REGION}" `
            --member "serviceAccount:${SA_CLOUD_RUN_DEV_EMAIL}" `
            --role roles/artifactregistry.reader `
            --project "${PROJECT_ID_MAIN}"

            gcloud beta builds triggers create github `
            --repo-name "${GITHUB_REPO_NAME}" `
            --repo-owner "${GITHUB_REPO_OWNER}" `
            --branch-pattern "^main$" `
            --build-config "build/cloudbuild-dev.yaml" `
            --name "deploy-dev" `
            --service-account "projects/${PROJECT_ID_MAIN}/serviceAccounts/${SA_BUILD_DEV_EMAIL}" `
            --project "${PROJECT_ID_MAIN}" `
            --substitutions _HOST="${HOST_DEV}"`,_DOCKER_REPO="${DEFAULT_REGION}-docker.pkg.dev/${PROJECT_ID_MAIN}/${ARTIFACT_REPO_NAME}"`,_PROJECT="${PROJECT_ID_DEV}"`,_TERRAFORM_BUCKET="${TERRAFORM_BUCKET_NAME}"

#            gcloud beta builds triggers create github `
#            --repo-name "${GITHUB_REPO_NAME}" `
#            --repo-owner "${GITHUB_REPO_OWNER}" `
#            --branch-pattern "^main$" `
#            --build-config "build/cloudbuild-feature.yaml" `
#            --name "build-feature" `
#            --service-account "projects/${PROJECT_ID_MAIN}/serviceAccounts/${SA_BUILD_DEV_EMAIL}" `
#            --project "${PROJECT_ID_MAIN}" `
#            --substitutions _HOST="${HOST_DEV}"`,_DOCKER_REPO="${DEFAULT_REGION}-docker.pkg.dev/${PROJECT_ID_MAIN}/${ARTIFACT_REPO_NAME}"`,_PROJECT="${PROJECT_ID_DEV}"`,_TERRAFORM_BUCKET="${TERRAFORM_BUCKET_NAME}"

            # TODO add feature branch script
        }

        if ($phase -contains "setupTest" -and -not($skip -contains "setupTest"))
        {

            $HOST_TEST = Read-Host "Enter domain for test"

            $host.ui.RawUI.ForegroundColor = 'DarkGreen'
            Write-Output "[setupTest] Creating test project"
            $host.ui.RawUI.ForegroundColor = $defaultForeground

            gcloud projects create "${PROJECT_ID_TEST}" `
            --name "${PROJECT_NAME_TEST}"

            gcloud beta billing projects link "${PROJECT_ID_TEST}" `
            --billing-account "$BILLING_ACCOUNT_ID"

            gcloud services enable `
            cloudresourcemanager.googleapis.com `
            compute.googleapis.com `
            iam.googleapis.com `
            --project "${PROJECT_ID_TEST}"

            Start-Sleep -Seconds 30

            gcloud iam service-accounts create "${SA_BUILD_TEST}" `
            --description "Build SA for test" `
            --display-name "Build SA TEST" `
            --project "${PROJECT_ID_MAIN}"

            gcloud projects add-iam-policy-binding "${PROJECT_ID_MAIN}" `
            --member "serviceAccount:${SA_BUILD_TEST_EMAIL}" `
            --role roles/cloudbuild.builds.builder `
            --project "${PROJECT_ID_MAIN}"

            gcloud projects add-iam-policy-binding "${PROJECT_ID_TEST}" `
            --member "serviceAccount:${SA_BUILD_TEST_EMAIL}" `
            --role roles/editor `
            --project "${PROJECT_ID_TEST}"

            gcloud projects add-iam-policy-binding "${PROJECT_ID_TEST}" `
            --member "serviceAccount:${SA_BUILD_TEST_EMAIL}" `
            --role roles/iam.securityAdmin `
            --project "${PROJECT_ID_TEST}"

            $SA_CLOUD_RUN_TEST_EMAIL = "service-$(gcloud projects describe "${PROJECT_ID_TEST}" `
            --format 'value(projectNumber)')@serverless-robot-prod.iam.gserviceaccount.com"

            gcloud artifacts repositories add-iam-policy-binding "${ARTIFACT_REPO_NAME}" `
            --location "${DEFAULT_REGION}" `
            --member "serviceAccount:${SA_CLOUD_RUN_TEST_EMAIL}" `
            --role roles/artifactregistry.reader `
            --project "${PROJECT_ID_MAIN}"

            gcloud beta builds triggers create github `
            --repo-name "${GITHUB_REPO_NAME}" `
            --repo-owner "${GITHUB_REPO_OWNER}" `
            --tag-pattern "^\d+\.\d+\.\d+$" `
            --build-config "build/cloudbuild-test.yaml" `
            --name "deploy-test" `
            --service-account "projects/${PROJECT_ID_MAIN}/serviceAccounts/${SA_BUILD_TEST_EMAIL}" `
            --project "${PROJECT_ID_MAIN}" `
            --substitutions _HOST="${HOST_TEST}"`,_DOCKER_REPO="${DEFAULT_REGION}-docker.pkg.dev/${PROJECT_ID_MAIN}/${ARTIFACT_REPO_NAME}"`,_PROJECT="${PROJECT_ID_DEV}"`,_TERRAFORM_BUCKET="${TERRAFORM_BUCKET_NAME}"

        }

        # TODO add prod
    }