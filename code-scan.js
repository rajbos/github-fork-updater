const { Octokit } = require("@octokit/rest");
const core = require("@actions/core");
const fs = require("fs");
const [token, repo, originalOwner, owner, issue_number, issue_token] =
  process.argv.slice(2);

const octokit = new Octokit({
  auth: token,
});

const issue_octokit = new Octokit({
  auth: issue_token,
});

const octokitFunctions = {
  getRepo: octokit.repos.get,
  delRepo: octokit.repos.delete,
  createFork: octokit.repos.createFork,
  enableDependabot: octokit.rest.repos.enableVulnerabilityAlerts,
  listAlertsForRepo: octokit.rest.dependabot.listAlertsForRepo,
  listScanningResult: octokit.rest.codeScanning.listAlertsForRepo,
  listLanguages: octokit.rest.repos.listLanguages,
  triggerCodeqlScan: octokit.rest.actions.createWorkflowDispatch,
  listWorkflowRuns: octokit.rest.actions.listWorkflowRunsForRepo,
  getWorkflowRun: octokit.rest.actions.getWorkflowRun,
};

async function wait(milliseconds) {
  return new Promise((_resolve) => {
    if (typeof milliseconds !== "number") {
      throw new Error("milliseconds not a number");
    }
    setTimeout(() => _resolve("done!"), milliseconds);
  });
}

async function octokitRequest(request, extraArgs = {}) {
  console.log(`Running ${request} function`);
  try {
    const requestProperties = { owner, repo, ...extraArgs };
    const response = await octokitFunctions[request](requestProperties);
    console.log(`Function ${request} finished succesfully`);
    return response;
  } catch (error) {
    console.log(`Failed to run ${request}: ${error.message}`);
  }
}

async function putRequest(request, extraProps = {}) {
  //generic function for PUT requests
  try {
    await octokit.request(`PUT /repos/{owner}/{repo}/${request}`, {
      owner,
      repo,
      ...extraProps,
    });
  } catch (error) {
    console.log(`Failed to run ${request}: ${error.message}`);
  }
}

async function pushWorkflowFile() {
  let languages = await octokitRequest("listLanguages");
  languages = Object.keys(languages.data);
  console.log(`Detected languages: ${languages} type: ${typeof languages}`);
  const supportedLanguages = [
    "TypeScript",
    "JavaScript",
    "Ruby",
    "Python",
    "Kotlin",
    "Go",
    "C++",
    "C#",
    "C",
  ];
  languages = languages.filter((item) => supportedLanguages.includes(item));
  if (languages.length) {
    console.log(`Add Codeql workflow file`);
    let workflowFile = fs.readFileSync("codeql-analysis-check.yml", "utf8");
    workflowFile = workflowFile.replace(
      "languageString",
      JSON.stringify(languages)
    );

    console.log(`Add Codeql workflow file`);

    try {
      await putRequest("contents/.github/workflows/codeql-analysis-check.yml", {
        path: ".github/workflows/check-and-validate-codeql.yml",
        message: "Inject codeql workflow",
        content: Buffer.from(workflowFile).toString("base64"),
      });
      console.log("Workflow file created successfully");
    } catch (error) {
      console.error("Error creating workflow file:", error);
    }
  } else {
    console.log("No supported languages for codeQL.");
    return "NoLanguages";
  }
}

async function waitForCodeqlScan() {
  console.log(`Get the dispatched run id`);
  const response = await octokitRequest("listWorkflowRuns", {
    event: "workflow_dispatch",
  });
  const run_id = response.data.workflow_runs[0].id;

  let status = "queued";
  while (status != "completed") {
    console.log(`Wait for scan to complete - Run id : ${run_id}`);
    await wait(15000);
    const run_status = await octokitRequest("getWorkflowRun", {
      run_id,
    });
    if (run_status.data.status == "completed") {
      status = run_status.data.status;
    }
  }
}

function checkForBlockingAlerts(codeScanningAlerts, dependabotAlerts) {
  let blocking = false;
  if (codeScanningAlerts) {
    codeScanningAlerts.forEach((alert) => {
      if (
        alert.rule.security_severity_level == "critical" ||
        alert.rule.security_severity_level == "high"
      ) {
        blocking = true;
      }
    });
  }
  dependabotAlerts.forEach((alert) => {
    if (
      alert.security_advisory.severity == "critical" ||
      alert.security_advisory.severity == "high"
    ) {
      blocking = true;
    }
  });

  return blocking;
}
async function checkForAlerts(codeqlScanAlerts = [], dependabotAlerts = []) {
  if (dependabotAlerts || codeqlScanAlerts) {
    if (checkForBlockingAlerts(codeqlScanAlerts.data, dependabotAlerts.data)) {
      core.setOutput("can-merge", "needs-manual-check");
      return "Blocking CodeQL scan and/pr Dependabot alerts";
    } else {
      core.setOutput("can-merge", "update-fork");
    }
  } else {
    core.setOutput("can-merge", "needs-manual-check");
    return "No CodeQL scan or Dependabot alerts found";
  }
}
async function run() {
  await octokitRequest("delRepo");
  const forkRepo = await octokitRequest("createFork", {
    owner: originalOwner,
    organization: owner,
  });

  await wait(5000);
  await putRequest("vulnerability-alerts"); // Enable dependabot

  await wait(5000);

  // Push Codeql.yml file
  
  let issueBody = "";
  const codeqlLanguagesError = await pushWorkflowFile();
  if (!codeqlLanguagesError) {
    //Trigger a scan
    await wait(15000);
    const codeqlStatus = await octokitRequest("triggerCodeqlScan", {
      workflow_id: `codeql-analysis-check.yml`,
      ref: forkRepo.data.parent.default_branch,
    });

    if (codeqlStatus.status == 204) {
      //Wait for the scan to complete
      console.log(`Wait for job to start !`);
      await wait(15000);
      await waitForCodeqlScan();

      const dependabotAlerts = await octokitRequest("listAlertsForRepo");
      const codeqlScanAlerts = await octokitRequest("listScanningResult");
      issueBody = checkForAlerts(codeqlScanAlerts, dependabotAlerts);
    } else {
      issueBody = "CodeQL scan injection failed";
      core.setOutput("can-merge", "needs-manual-check");
    }
  } else {
    await wait(60000); // Since we don't know how long dependabot will take to scan the wait is 1 minute.
    const dependabotAlerts = await octokitRequest("listAlertsForRepo");
    checkForAlerts([], dependabotAlerts);
  }
  issue_owner = "asml-actions";
  issue_repo = "github-fork-updater";
  if (issueBody.length > 0) {
    console.log(
      `Creating a new comment in issue [${issue_number}] in repo [${issue_owner}/${issue_repo}] to indicate status: [${issueBody}]`
    );
    // create an comment in the issue to indicate why a manual check is needed. uses different client!
    issue_octokit.rest.issues.createComment({
      owner: issue_owner,
      repo: issue_repo,
      issue_number,
      body: issueBody,
    });
  } else {
    console.log(`No issues with the checks`);
  }
}

run();
