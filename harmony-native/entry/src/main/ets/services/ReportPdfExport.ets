import { picker, fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ApiError } from '../model/Contracts';
import { globalReportId, validateReportPdf } from '../model/GlobalHealthReports';

// No private report is written to a cache or a guessed public directory.
// The caller binds this callback to the initiating account and page generation.
export async function saveReportPdf(context: common.UIAbilityContext, id: string, bytes: ArrayBuffer,
  stillAuthorized: () => boolean): Promise<boolean> {
  const name = `saydian-health-report-${globalReportId(id)}.pdf`;
  validateReportPdf(bytes);
  if (!stillAuthorized()) throw new ApiError('reports_export_failed');
  let file: fileIo.File | undefined = undefined;
  try {
    const chooser = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [name]; options.fileSuffixChoices = ['PDF|.pdf'];
    const selected = await chooser.save(options);
    if (!selected.length) return false;
    if (selected.length !== 1 || !selected[0] || !stillAuthorized()) throw new ApiError('reports_export_failed');
    file = await fileIo.open(selected[0], fileIo.OpenMode.READ_WRITE);
    if (!stillAuthorized()) throw new ApiError('reports_export_failed');
    // Picker handles destination choice/overwrite confirmation. Do not delete a selected user file on failure.
    await fileIo.truncate(file.fd, 0);
    if (!stillAuthorized()) throw new ApiError('reports_export_failed');
    const written = await fileIo.write(file.fd, bytes);
    if (written !== bytes.byteLength) throw new ApiError('reports_export_failed');
    await fileIo.fsync(file.fd);
    if ((await fileIo.stat(file.fd)).size !== bytes.byteLength) throw new ApiError('reports_export_failed');
    if (!stillAuthorized()) throw new ApiError('reports_export_failed');
    return true;
  } catch {
    throw new ApiError('reports_export_failed');
  } finally {
    if (file) { try { await fileIo.close(file); } catch { throw new ApiError('reports_export_failed'); } }
  }
}
