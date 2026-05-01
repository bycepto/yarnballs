const root = document.getElementById("main");

if (root) {
  root.innerHTML = `
    <main style="display:grid;min-height:100vh;place-items:center;padding:2rem;text-align:center">
      <div>
        <h1 style="margin:0 0 1rem">Yarnballs Go Backend</h1>
        <p style="margin:0;color:#94a3b8">
          The Go server skeleton is running. Elm asset integration is the next step.
        </p>
      </div>
    </main>
  `;
}
