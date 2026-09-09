import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { camera } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

function friendlyCameraError(error: Error): Error {
  const code = Number((error as BusinessError).code ?? 0);
  if (code === 201) return new Error('请允许相机权限后使用手表遥控拍照');
  if (code === 7400102) return new Error('相机正被其他应用使用，请关闭后重试');
  if (code === 7400104) return new Error('相机尚未准备好，请稍后重试');
  const known = ['相机操作已取消', '当前手机没有可用相机', '当前手机不支持标准拍照模式',
    '当前手机没有可用的相机输出规格', '请允许相机权限后使用手表遥控拍照'];
  return new Error(known.includes(error.message) ? error.message : '相机暂时无法使用，请稍后重试');
}

export class HarmonyCameraController {
  private manager: camera.CameraManager | undefined = undefined;
  private input: camera.CameraInput | undefined = undefined;
  private preview: camera.PreviewOutput | undefined = undefined;
  private photo: camera.PhotoOutput | undefined = undefined;
  private session: camera.PhotoSession | undefined = undefined;
  private helper: photoAccessHelper.PhotoAccessHelper | undefined = undefined;
  private context: common.UIAbilityContext | undefined = undefined;
  private ready: boolean = false;
  private lifecycleGeneration: number = 0;
  private tail: Promise<void> = Promise.resolve();
  private capturePromise: Promise<string> | undefined = undefined;
  private captureResolve: ((uri: string) => void) | undefined = undefined;
  private captureReject: ((error: Error) => void) | undefined = undefined;
  private captureTimer: number = -1;

  isReady(): boolean { return this.ready; }

  start(context: common.UIAbilityContext, surfaceId: string): Promise<void> {
    const generation = ++this.lifecycleGeneration;
    return this.enqueue(async (): Promise<void> => this.startNow(context, surfaceId, generation));
  }

  stop(): Promise<void> {
    ++this.lifecycleGeneration;
    this.cancelCapture(new Error('拍照已取消'));
    return this.enqueue(async (): Promise<void> => this.releaseResources());
  }

  capture(): Promise<string> {
    return this.enqueue(async (): Promise<string> => this.captureNow());
  }

  private enqueue<T>(action: () => Promise<T>): Promise<T> {
    const result: Promise<T> = this.tail.then(async (): Promise<T> => action());
    this.tail = result.then((): void => {}, (): void => {});
    return result;
  }

  private async startNow(context: common.UIAbilityContext, surfaceId: string, generation: number): Promise<void> {
    await this.releaseResources();
    if (!surfaceId.trim()) throw new Error('相机预览区域尚未准备好，请稍后重试');
    try {
      await this.requestCameraPermission(context);
      this.requireCurrent(generation);
      const manager = camera.getCameraManager(context);
      const cameras = manager.getSupportedCameras();
      const device = cameras.find((item: camera.CameraDevice) =>
        item.cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK) ?? cameras[0];
      if (!device) throw new Error('当前手机没有可用相机');
      const modes = manager.getSupportedSceneModes(device);
      if (!modes.includes(camera.SceneMode.NORMAL_PHOTO)) throw new Error('当前手机不支持标准拍照模式');
      const capability = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
      if (!capability.previewProfiles.length || !capability.photoProfiles.length) {
        throw new Error('当前手机没有可用的相机输出规格');
      }
      const previewProfile = this.chooseProfile(capability.previewProfiles, 1280 * 960);
      const photoProfile = this.chooseProfile(capability.photoProfiles, 12 * 1024 * 1024);
      const input = manager.createCameraInput(device);
      this.manager = manager; this.input = input;
      await input.open();
      this.requireCurrent(generation);
      const preview = manager.createPreviewOutput(previewProfile, surfaceId);
      const photo = manager.createPhotoOutput(photoProfile);
      const session = manager.createSession<camera.PhotoSession>(camera.SceneMode.NORMAL_PHOTO);
      this.preview = preview; this.photo = photo; this.session = session;
      photo.on('photoAssetAvailable', this.onPhotoAssetAvailable);
      session.beginConfig();
      session.addInput(input);
      session.addOutput(preview);
      session.addOutput(photo);
      await session.commitConfig();
      this.requireCurrent(generation);
      const screenRotation = display.getDefaultDisplaySync().rotation;
      preview.setPreviewRotation(preview.getPreviewRotation(screenRotation), true);
      await session.start();
      this.requireCurrent(generation);
      this.helper = photoAccessHelper.getPhotoAccessHelper(context); this.context = context; this.ready = true;
    } catch (error) {
      await this.releaseResources();
      throw friendlyCameraError(error as Error);
    }
  }

  private async captureNow(): Promise<string> {
    if (!this.ready || !this.photo || !this.context || !this.helper) throw new Error('相机尚未准备好，请先开启相机遥控');
    if (this.capturePromise) return this.capturePromise;
    const pending = new Promise<string>((resolve: (uri: string) => void, reject: (error: Error) => void) => {
      this.captureResolve = resolve; this.captureReject = reject;
    });
    this.capturePromise = pending;
    this.captureTimer = setTimeout(() => this.cancelCapture(new Error('拍照保存超时，请重试')), 12000);
    try {
      const rotation = this.photo.getPhotoRotation(display.getDefaultDisplaySync().rotation);
      await this.photo.capture({ quality: camera.QualityLevel.QUALITY_LEVEL_HIGH, rotation: rotation, mirror: false });
    } catch (error) {
      this.cancelCapture(friendlyCameraError(error as Error));
    }
    return pending;
  }

  private onPhotoAssetAvailable = async (error: BusinessError, asset: photoAccessHelper.PhotoAsset): Promise<void> => {
    if (error && Number(error.code ?? 0) !== 0) {
      this.cancelCapture(friendlyCameraError(error));
      return;
    }
    if (!asset || !this.helper || !this.captureResolve) {
      await this.discardPhoto(asset);
      return;
    }
    try {
      const request = new photoAccessHelper.MediaAssetChangeRequest(asset);
      request.saveCameraPhoto(photoAccessHelper.ImageFileType.JPEG);
      await this.helper.applyChanges(request);
      const resolve = this.captureResolve;
      this.clearCaptureState();
      resolve(asset.uri);
    } catch (saveError) {
      await this.discardPhoto(asset);
      this.cancelCapture(friendlyCameraError(saveError as Error));
    }
  };

  private async discardPhoto(asset?: photoAccessHelper.PhotoAsset): Promise<void> {
    if (!asset || !this.helper) return;
    try {
      const request = new photoAccessHelper.MediaAssetChangeRequest(asset);
      request.discardCameraPhoto();
      await this.helper.applyChanges(request);
    } catch {}
  }

  private cancelCapture(error: Error): void {
    const reject = this.captureReject;
    this.clearCaptureState();
    reject?.(error);
  }

  private clearCaptureState(): void {
    if (this.captureTimer >= 0) clearTimeout(this.captureTimer);
    this.captureTimer = -1; this.capturePromise = undefined; this.captureResolve = undefined; this.captureReject = undefined;
  }

  private async releaseResources(): Promise<void> {
    this.ready = false;
    this.cancelCapture(new Error('拍照已取消'));
    const session = this.session, preview = this.preview, photo = this.photo, input = this.input, helper = this.helper;
    this.session = undefined; this.preview = undefined; this.photo = undefined; this.input = undefined;
    this.helper = undefined; this.manager = undefined; this.context = undefined;
    try { photo?.off('photoAssetAvailable', this.onPhotoAssetAvailable); } catch {}
    try { await session?.stop(); } catch {}
    try { await session?.release(); } catch {}
    try { await preview?.release(); } catch {}
    try { await photo?.release(); } catch {}
    try { await input?.close(); } catch {}
    try { await helper?.release(); } catch {}
  }

  private async requestCameraPermission(context: common.UIAbilityContext): Promise<void> {
    const permissions: Permissions[] = ['ohos.permission.CAMERA'];
    const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, permissions);
    if (result.authResults.some((value: number) => value !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED)) {
      throw new Error('请允许相机权限后使用手表遥控拍照');
    }
  }

  private requireCurrent(generation: number): void {
    if (generation !== this.lifecycleGeneration) throw new Error('相机操作已取消');
  }

  private chooseProfile(profiles: camera.Profile[], targetPixels: number): camera.Profile {
    let best = profiles[0];
    let bestScore = Number.MAX_VALUE;
    profiles.forEach((profile: camera.Profile) => {
      const width = Math.max(1, profile.size.width), height = Math.max(1, profile.size.height);
      const ratio = Math.max(width, height) / Math.min(width, height);
      const ratioPenalty = Math.abs(ratio - 4 / 3) * 100;
      const pixels = width * height;
      const sizePenalty = Math.abs(pixels - targetPixels) / Math.max(1, targetPixels);
      const score = ratioPenalty + sizePenalty;
      if (score < bestScore) { best = profile; bestScore = score; }
    });
    return best;
  }
}

export const harmonyCamera: HarmonyCameraController = new HarmonyCameraController();
