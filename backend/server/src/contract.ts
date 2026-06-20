import { existsSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  Ajv2020,
  type ErrorObject,
  type ValidateFunction,
} from "ajv/dist/2020.js";
import type { FormatsPlugin } from "ajv-formats";
import YAML from "yaml";

import type { JsonObject } from "./types.js";

type OpenApiDocument = {
  info: { version: string };
  components: {
    schemas: Record<string, JsonObject>;
    examples: Record<string, { value: unknown }>;
  };
};

const contractCandidates = [
  fileURLToPath(
    new URL("../../../contracts/openapi.yaml", import.meta.url),
  ),
  fileURLToPath(
    new URL("../../../../contracts/openapi.yaml", import.meta.url),
  ),
  resolve(process.cwd(), "contracts/openapi.yaml"),
  resolve(process.cwd(), "../../contracts/openapi.yaml"),
];
const contractPath = contractCandidates.find(existsSync);

if (contractPath === undefined) {
  throw new Error("Unable to locate contracts/openapi.yaml");
}

const require = createRequire(import.meta.url);
const addFormats = require("ajv-formats") as FormatsPlugin;
const document = YAML.parse(
  readFileSync(contractPath, "utf8"),
) as OpenApiDocument;

if (document.info.version !== "1.1.0") {
  throw new Error(
    `Expected OpenAPI contract 1.1.0, received ${document.info.version}`,
  );
}

function rewriteSchemaReferences(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(rewriteSchemaReferences);
  }

  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => {
        if (
          key === "$ref" &&
          typeof child === "string" &&
          child.startsWith("#/components/schemas/")
        ) {
          return [
            key,
            child.replace("#/components/schemas/", "#/$defs/"),
          ];
        }

        return [key, rewriteSchemaReferences(child)];
      }),
    );
  }

  return value;
}

const schemaRoot = {
  $id: "https://easylife.local/openapi-v1.1.0-schemas.json",
  $schema: "https://json-schema.org/draft/2020-12/schema",
  $defs: rewriteSchemaReferences(document.components.schemas),
};

const ajv = new Ajv2020({
  allErrors: true,
  strict: false,
});
addFormats(ajv);
ajv.addSchema(schemaRoot);

const validators = new Map<string, ValidateFunction>();

export function validateContractSchema(
  schemaName: string,
  value: unknown,
): { valid: true } | { valid: false; errors: ErrorObject[] } {
  let validate = validators.get(schemaName);

  if (validate === undefined) {
    const compiled = ajv.compile({
      $ref: `${schemaRoot.$id}#/$defs/${schemaName}`,
    });
    validators.set(schemaName, compiled);
    validate = compiled;
  }

  if (validate(value)) {
    return { valid: true };
  }

  return { valid: false, errors: validate.errors ?? [] };
}

export function contractExample<T>(name: string): T {
  const example = document.components.examples[name];

  if (example === undefined) {
    throw new Error(`OpenAPI example ${name} does not exist`);
  }

  return structuredClone(example.value) as T;
}

export const contractVersion = document.info.version;
