import { test, expect } from "@playwright/test";
test("mobile onboarding saves before continuing", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/login");
  await page.getByLabel("Email address").fill("ada@example.test");
  await page.getByLabel("Password", { exact: true }).fill("test-password");
  await page.getByRole("button", { name: "Sign in →" }).click();
  await expect(
    page.getByRole("heading", { name: "A little progress, Ada." }),
  ).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBeTruthy();
  await page.screenshot({
    path: "test-results/dashboard-mobile.png",
    fullPage: true,
  });
  await page.getByRole('button',{name:'Menu · Overview'}).click();
  await page.getByRole('link',{name:'Saved',exact:true}).click();
  await expect(page).toHaveURL(/\/app\/saved/);
  await expect(page.getByRole('button',{name:'Menu · Saved'})).toHaveAttribute('aria-expanded','false');
  await page.goto("/onboarding");
  await page.getByLabel("CGPA (optional, 0–5)").fill("4.2");
  await page.getByRole("button", { name: "Save and continue →" }).click();
  await expect(page).toHaveURL(/step=2/);
  await page.goto("/app/profile");
  await expect(page.getByLabel("CGPA (optional, 0–5)")).toHaveValue("4.2");
});
test("student journey: login, save, consent, feedback, persistence, logout", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("Email address").fill("ada@example.test");
  await page.getByLabel("Password", { exact: true }).fill("test-password");
  await page.getByRole("button", { name: "Sign in →" }).click();
  await expect(
    page.getByRole("heading", { name: "A little progress, Ada." }),
  ).toBeVisible();
  await page.screenshot({
    path: "test-results/dashboard-desktop.png",
    fullPage: true,
  });
  await page.getByRole("link", { name: "Opportunities", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Your next opportunity is out there." }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Save", exact: true }).first().click();
  await expect(page.getByRole("status")).toContainText("Opportunity saved");
  await page.getByRole("link", { name: "Saved", exact: true }).click();
  await expect(page.locator(".opportunity-card")).toHaveCount(1);
  await page.reload();
  await expect(page.locator(".opportunity-card")).toHaveCount(1);
  await page.getByRole("link", { name: "My profile", exact: true }).click();
  await page.getByLabel("Full name").fill("Ada Student");
  await page.getByLabel("CGPA (optional, 0–5)").fill("4.10");
  await page.getByRole("button", { name: "Save profile", exact: true }).click();
  await expect(page.getByRole("status")).toContainText("Profile saved");
  await page.reload();
  await expect(page.getByLabel("CGPA (optional, 0–5)")).toHaveValue("4.1");
  await page
    .getByLabel("Use my profile for personalized recommendations")
    .uncheck();
  await page.getByRole("button", { name: "Save profile", exact: true }).click();
  await expect(page.getByRole("status")).toContainText("paused");
  await page.getByRole("link", { name: "Skill roadmap", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Give your next step a direction." }),
  ).toBeVisible();
  await page
    .getByRole("link", { name: "Help & feedback", exact: true })
    .click();
  await page.getByLabel("What would you like to share?").selectOption("idea");
  await page
    .getByLabel("Tell us more")
    .fill("Please add more local internship opportunities.");
  await page.getByRole("button", { name: "Send feedback →" }).click();
  await expect(page.getByRole("status")).toContainText("recorded");
  await expect(page.locator(".report-row")).toContainText("local internship");
  await page.goto("/app/admin");
  await expect(page.getByText("This page could not be found.")).toBeVisible();
  await page.goto("/app");
  await page.getByRole("button", { name: "Log out" }).click();
  await expect(page).toHaveURL(/login/);
  await page.goto("/app");
  await expect(page).toHaveURL(/login/);
});
test("public mobile pages fit and have usable navigation", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Your potential. A clearer path." }),
  ).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBeTruthy();
  await page.screenshot({
    path: "test-results/landing-mobile.png",
    fullPage: true,
  });
  await page.getByRole("link", { name: "Find my next step" }).click();
  await expect(page.getByLabel("Full name")).toBeVisible();
  await page.screenshot({
    path: "test-results/signup-mobile.png",
    fullPage: true,
  });
});
test("invalid login is actionable without disclosing details", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByLabel("Email address").fill("ada@example.test");
  await page.getByLabel("Password", { exact: true }).fill("wrong-password");
  await page.getByRole("button", { name: "Sign in →" }).click();
  await expect(page.locator("form [role=alert]")).toContainText("do not match");
  await expect(page.getByLabel("Email address")).toHaveValue(
    "ada@example.test",
  );
});
test("administrator can review feedback and export it", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email address").fill("admin@example.test");
  await page.getByLabel("Password", { exact: true }).fill("test-password");
  await page.getByRole("button", { name: "Sign in →" }).click();
  await expect(
    page.getByRole("heading", { name: "A little progress, Ada." }),
  ).toBeVisible();
  await page.goto("/app/admin");
  await expect(
    page.getByText("Please add more local internship opportunities."),
  ).toBeVisible();
  await page
    .locator(".form-card")
    .getByRole("combobox", { name: "Status", exact: true })
    .selectOption("reviewing");
  await page
    .getByLabel("Internal note")
    .fill("Check available local providers.");
  await page.getByRole("button", { name: "Save review" }).click();
  await expect(page.getByRole("status")).toContainText("Review saved");
  await page.reload();
  await expect(page.locator(".internal-note")).toContainText(
    "Check available local providers.",
  );
  const download = page.waitForEvent("download");
  await page.getByRole("link", { name: "Export feedback CSV ↓" }).click();
  expect((await download).suggestedFilename()).toBe("nexus-feedback.csv");
});
