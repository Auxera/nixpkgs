type ExecOptions = {
  cwd?: string;
  stream?: boolean;
};

export type ExecResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
};

async function collect(
  stream: ReadableStream<Uint8Array> | null,
  output: NodeJS.WriteStream,
  enabled: boolean,
): Promise<string> {
  if (!stream) {
    return "";
  }

  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let text = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    const chunk = decoder.decode(value, { stream: true });
    text += chunk;
    if (enabled) {
      output.write(chunk);
    }
  }

  const last = decoder.decode();
  if (last.length > 0) {
    text += last;
    if (enabled) {
      output.write(last);
    }
  }

  return text;
}

export async function exec(command: string[], options: ExecOptions = {}): Promise<ExecResult> {
  const proc = Bun.spawn(command, {
    cwd: options.cwd ?? process.cwd(),
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
  });

  const stream = options.stream ?? true;
  const [stdout, stderr, exitCode] = await Promise.all([
    collect(proc.stdout, process.stdout, stream),
    collect(proc.stderr, process.stderr, stream),
    proc.exited,
  ]);

  return { stdout, stderr, exitCode };
}

export async function checkedExec(command: string[], options: ExecOptions = {}): Promise<ExecResult> {
  const result = await exec(command, options);
  if (result.exitCode !== 0) {
    throw new Error(`command failed: ${command.join(" ")}\n${result.stderr}`);
  }
  return result;
}
