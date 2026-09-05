@Component
export struct ArticleImage {
  @Prop source: string = '';
  @Prop description: string = '文章配图';
  @State private failed: boolean = false;
  @State private loading: boolean = true;
  @State private ratio: number = 1.5;
  private timeoutId: number = -1;

  aboutToAppear(): void { this.startTimeout(); }
  aboutToDisappear(): void { this.stopTimeout(); }

  private stopTimeout(): void {
    if (this.timeoutId >= 0) clearTimeout(this.timeoutId);
    this.timeoutId = -1;
  }

  private startTimeout(): void {
    this.stopTimeout();
    this.timeoutId = setTimeout(() => {
      this.loading = false;
      this.failed = true;
      this.timeoutId = -1;
    }, 15000);
  }

  build() {
    Column({ space: 10 }) {
      if (this.failed) {
        Text('配图加载失败，文字内容仍可阅读').fontSize(14).fontColor('#747783')
        Button('重试加载图片').constraintSize({ minHeight: 48 }).fontColor('#D7082E')
          .backgroundColor(Color.White).onClick(() => {
            this.loading = true;
            this.failed = false;
            this.startTimeout();
          })
      } else {
        if (this.loading) { Text('正在加载配图…').fontSize(14).fontColor('#747783') }
        Image(this.source).width('100%').aspectRatio(this.ratio).objectFit(ImageFit.Contain).autoResize(true)
          .backgroundColor('#FFFCFB').borderRadius(18).clip(true)
          .accessibilityText(this.description)
          .onComplete((event) => {
            if (event && event.width > 0 && event.height > 0) {
              this.ratio = Math.max(0.05, Math.min(10, event.width / event.height));
            }
            this.loading = false;
            this.stopTimeout();
          })
          .onError(() => { this.failed = true; this.loading = false; this.stopTimeout(); })
      }
    }.width('100%').borderRadius(18)
  }
}
