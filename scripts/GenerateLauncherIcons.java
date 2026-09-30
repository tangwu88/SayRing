import java.awt.AlphaComposite;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.imageio.ImageIO;

/** Cross-platform mechanical exporter for the approved Say Ring launcher artwork. */
public final class GenerateLauncherIcons {
  private static final double ANDROID_CORNER_RADIUS = 0.223;
  private static final double ADAPTIVE_INSET = (1.0 - 66.0 / 108.0) / 2.0;

  private final Path root;
  private final boolean checkOnly;
  private int outputCount;

  private GenerateLauncherIcons(Path root, boolean checkOnly) {
    this.root = root;
    this.checkOnly = checkOnly;
  }

  public static void main(String[] args) throws Exception {
    boolean checkOnly = args.length == 1 && "--check".equals(args[0]);
    if (args.length > (checkOnly ? 1 : 0)) {
      throw new IllegalArgumentException("Usage: java scripts/GenerateLauncherIcons.java [--check]");
    }
    new GenerateLauncherIcons(Path.of("").toAbsolutePath().normalize(), checkOnly).run();
  }

  private void run() throws Exception {
    Path sourcePath = root.resolve("assets/branding/app_icon_source.png");
    byte[] sourceBytes = Files.readAllBytes(sourcePath);
    BufferedImage source = ImageIO.read(sourcePath.toFile());
    if (source == null || source.getWidth() != source.getHeight() || source.getWidth() < 1024) {
      throw new IllegalStateException("The approved source must be a square PNG at least 1024 px wide");
    }

    BufferedImage master = renderRgb(source, 1024, 0.0);
    export("assets/branding/saidian-launcher-master.png", master);
    export("assets/branding/saidian-launcher-rounded.png", renderArgb(master, 1024, 0.0, true));
    export("assets/branding/saidian-launcher-foreground.png", renderArgb(master, 1024, ADAPTIVE_INSET, false));

    String iosBase = "ios/Runner/Assets.xcassets/AppIcon.appiconset/";
    export(iosBase + "Icon-App-1024x1024@1x.png", master);
    Map<String, Integer> iosSizes = new LinkedHashMap<>();
    iosSizes.put("Icon-App-20x20@1x.png", 20);
    iosSizes.put("Icon-App-20x20@2x.png", 40);
    iosSizes.put("Icon-App-20x20@3x.png", 60);
    iosSizes.put("Icon-App-29x29@1x.png", 29);
    iosSizes.put("Icon-App-29x29@2x.png", 58);
    iosSizes.put("Icon-App-29x29@3x.png", 87);
    iosSizes.put("Icon-App-40x40@1x.png", 40);
    iosSizes.put("Icon-App-40x40@2x.png", 80);
    iosSizes.put("Icon-App-40x40@3x.png", 120);
    iosSizes.put("Icon-App-60x60@2x.png", 120);
    iosSizes.put("Icon-App-60x60@3x.png", 180);
    iosSizes.put("Icon-App-76x76@1x.png", 76);
    iosSizes.put("Icon-App-76x76@2x.png", 152);
    iosSizes.put("Icon-App-83.5x83.5@2x.png", 167);
    for (Map.Entry<String, Integer> entry : iosSizes.entrySet()) {
      export(iosBase + entry.getKey(), renderRgb(master, entry.getValue(), 0.0));
    }

    export("harmony-native/AppScope/resources/base/media/app_icon_v3.png", master);
    String androidBase = "android/app/src/main/res/";
    String[] densities = {"mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"};
    int[] legacySizes = {48, 72, 96, 144, 192};
    int[] adaptiveSizes = {108, 162, 216, 324, 432};
    for (int index = 0; index < densities.length; index++) {
      BufferedImage legacy = renderArgb(master, legacySizes[index], 0.0, true);
      export(androidBase + "mipmap-" + densities[index] + "/ic_launcher.png", legacy);
      export(androidBase + "mipmap-" + densities[index] + "/ic_launcher_round.png", legacy);
      BufferedImage foreground = renderArgb(master, adaptiveSizes[index], ADAPTIVE_INSET, false);
      export(androidBase + "drawable-" + densities[index] + "/ic_launcher_foreground.png", foreground);
      export(androidBase + "drawable-" + densities[index] + "/ic_launcher_monochrome.png", monochrome(foreground));
    }

    System.out.printf(
        "%s %d launcher resources; source SHA256 %s; master SHA256 %s%n",
        checkOnly ? "Verified" : "Exported", outputCount, sha256(sourceBytes), sha256(png(master)));
  }

  private static void configure(Graphics2D graphics) {
    graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
    graphics.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
    graphics.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
    graphics.setRenderingHint(RenderingHints.KEY_ALPHA_INTERPOLATION, RenderingHints.VALUE_ALPHA_INTERPOLATION_QUALITY);
  }

  private static BufferedImage renderRgb(BufferedImage source, int size, double inset) {
    BufferedImage target = new BufferedImage(size, size, BufferedImage.TYPE_INT_RGB);
    Graphics2D graphics = target.createGraphics();
    configure(graphics);
    graphics.setColor(Color.WHITE);
    graphics.fillRect(0, 0, size, size);
    draw(graphics, source, size, inset);
    graphics.dispose();
    return target;
  }

  private static BufferedImage renderArgb(BufferedImage source, int size, double inset, boolean rounded) {
    BufferedImage target = new BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB);
    Graphics2D graphics = target.createGraphics();
    configure(graphics);
    graphics.setComposite(AlphaComposite.Src);
    if (rounded) {
      double arc = size * ANDROID_CORNER_RADIUS * 2.0;
      graphics.setClip(new RoundRectangle2D.Double(0, 0, size, size, arc, arc));
    }
    draw(graphics, source, size, inset);
    graphics.dispose();
    return target;
  }

  private static void draw(Graphics2D graphics, BufferedImage source, int size, double inset) {
    int offset = (int) Math.round(size * inset);
    int extent = size - 2 * offset;
    graphics.drawImage(source, offset, offset, extent, extent, null);
  }

  private static BufferedImage monochrome(BufferedImage source) {
    BufferedImage target = new BufferedImage(source.getWidth(), source.getHeight(), BufferedImage.TYPE_INT_ARGB);
    for (int y = 0; y < source.getHeight(); y++) {
      for (int x = 0; x < source.getWidth(); x++) {
        int argb = source.getRGB(x, y);
        int alpha = (argb >>> 24) & 0xff;
        int red = (argb >>> 16) & 0xff;
        int green = (argb >>> 8) & 0xff;
        int blue = argb & 0xff;
        int luminance = (int) Math.round(red * 0.2126 + green * 0.7152 + blue * 0.0722);
        int coverage = alpha * (255 - luminance) / 255;
        target.setRGB(x, y, coverage << 24);
      }
    }
    return target;
  }

  private void export(String relativePath, BufferedImage image) throws Exception {
    byte[] bytes = png(image);
    Path destination = root.resolve(relativePath);
    if (checkOnly) {
      if (!Files.exists(destination) || !MessageDigest.isEqual(bytes, Files.readAllBytes(destination))) {
        throw new IllegalStateException("Outdated icon: " + relativePath);
      }
    } else {
      Files.createDirectories(destination.getParent());
      Path temporary = Files.createTempFile(destination.getParent(), destination.getFileName().toString(), ".tmp");
      Files.write(temporary, bytes);
      try {
        Files.move(temporary, destination, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
      } catch (AtomicMoveNotSupportedException error) {
        Files.move(temporary, destination, StandardCopyOption.REPLACE_EXISTING);
      }
    }
    outputCount++;
  }

  private static byte[] png(BufferedImage image) throws IOException {
    ByteArrayOutputStream output = new ByteArrayOutputStream();
    if (!ImageIO.write(image, "png", output)) {
      throw new IOException("PNG encoder unavailable");
    }
    return output.toByteArray();
  }

  private static String sha256(byte[] bytes) throws Exception {
    byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
    StringBuilder value = new StringBuilder();
    for (byte item : digest) value.append(String.format("%02x", item));
    return value.toString();
  }
}
