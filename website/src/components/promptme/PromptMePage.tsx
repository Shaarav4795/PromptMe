import { CapabilityCardsSection } from "./CapabilityCardsSection";
import { CashbackBrandsSection } from "./CashbackBrandsSection";
import { FeatureSplitTwoSection } from "./FeatureSplitTwoSection";
import { HeaderSection } from "./HeaderSection";
import { HeroSection } from "./HeroSection";
import { PromptMeInteractions } from "./PromptMeInteractions";
import { OnboardingStepsSection } from "./OnboardingStepsSection";

export function PromptMePage() {
  return (
    <div className="pm-page">
      <HeaderSection />

      <main className="pm-page-main">
        <HeroSection />
        <CapabilityCardsSection />
        <FeatureSplitTwoSection />
        <CashbackBrandsSection />
        <OnboardingStepsSection />
      </main>
      <PromptMeInteractions />
    </div>
  );
}
