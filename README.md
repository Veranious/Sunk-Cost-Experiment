# Sunk-Cost-Experiment
Bpod Code for Sunk Cost Experiment

The project investigates the sunk cost fallacy in rats — the tendency to persist in a poor decision because of resources already invested, rather than evaluating future expected returns. The theoretical background comes from Ott et al. (2022, Science Advances), which argues that prior evidence for sunk cost sensitivity in animals (Sweis et al.) is confounded by a statistical artifact called attrition bias. My experiment aims to build a cleaner behavioural task that can dissociate true sunk cost sensitivity from this confound.

Here, the experiment runs on Bpod (a rodent behaviour system by Sanworks). There are three ports. The rat initiates a trial at Port 2, hears an offer tone whose frequency encodes the cost of the offer (higher Hz = shorter wait = better offer), then decides at Port 1 (reject) or Port 3 (accept). If it accepts, the tone decreases in frequency over time until it hits a threshold, at which point reward is delivered. If the rat exits Port 3 before the threshold is reached, it loses the reward. A grace period of 2 seconds allows brief exits before counting as a rejection.
