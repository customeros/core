import { globSync } from 'glob';
import { exec } from 'child_process';

/**
 * This script is used to generate Tailwind CSS variants for each UI kit component.
 * It will search for all `codegen-variants.ts` files in the `ui` directory and run them using `ts-node`.
 * The generated variants will be saved nearby the `codegen-variants.ts` file and should contain the name
 * of the component.
 *
 * example of output file:
 * Button.variants.ts
 */

const files = globSync('**/codegen-variants.ts', {
  ignore: 'node_modules/**',
});

files.forEach((file: string) => {
  exec(`npx tsx ${file}`, (err: unknown, stdout: unknown, stderr: unknown) => {
    if (err) {
      // eslint-disable-next-line no-console
      console.error(err);

      return;
    }

    // eslint-disable-next-line no-console
    console.info(stdout, stderr);
  });
});
