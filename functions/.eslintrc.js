module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "index.js", // Temporarily ignore index.js
  ],
  rules: {
    "quotes": ["error", "double"],
    "indent": ["error", 2],
  },
  overrides: [
    {
      files: ["*.ts"],
      extends: [
        "eslint:recommended",
        "plugin:import/errors",
        "plugin:import/warnings",
        "plugin:import/typescript",
        "google",
        "plugin:@typescript-eslint/recommended",
      ],
      parser: "@typescript-eslint/parser",
      parserOptions: {
        project: ["tsconfig.json", "tsconfig.dev.json"],
        sourceType: "module",
      },
      plugins: [
        "@typescript-eslint",
        "import",
      ],
      rules: {
        "quotes": ["error", "double"],
        "import/no-unresolved": 0,
        "indent": ["error", 2],
      },
    },
  ],
};
