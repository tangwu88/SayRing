"""仅离线研究：不接入App日期输出，不读用户数据库，不发网络请求。
输入必须为独立授权研究数据，保留预测时点与接收时间；参与者开发/验收分组互斥。
"""
import argparse
import datetime as dt
import json
import math
import random
import statistics as st

MODEL_VERSION = 'cycle-hazard-shadow-v1'
RELEASED = False

def day(value):
    parsed = dt.date.fromisoformat(value)
    if parsed.isoformat() != value:
        raise ValueError('invalid_calendar_date')
    return parsed

def validate(data):
    if data.get('researchConsented') is not True:
        raise ValueError('separate_research_authorization_required')
    rows = data['rows']
    groups = {}
    for row in rows:
        who, cohort = row['participant'], row['cohort']
        if cohort not in ('development', 'test') or who in groups and groups[who] != cohort:
            raise ValueError('participant_split_leakage')
        groups[who] = cohort
        as_of = day(row['asOf'])
        if row['leadDays'] not in (3, 7) or (day(row['actualStart']) - as_of).days != row['leadDays']:
            raise ValueError('invalid_frozen_forecast_time')
        for feature in row.get('temperature', []):
            if day(feature['date']) > as_of or day(feature['availableOn']) > as_of:
                raise ValueError('future_feature_leakage')
            if feature.get('qualified') is not True or not isinstance(feature.get('deviation'), (int, float)) or not math.isfinite(feature['deviation']):
                raise ValueError('unqualified_temperature')
        lengths = row['priorLengths'][-6:]
        if len(lengths) < 3 or any(not isinstance(n, int) or n <= 0 for n in lengths):
            raise ValueError('calendar_baseline_required')
        if day(row['lastStart']) > as_of:
            raise ValueError('future_period_leakage')
    return rows

def features(row, offset):
    lengths = row['priorLengths'][-6:]
    samples = sorted(row.get('temperature', []), key=lambda t: t['date'])
    current = (day(row['asOf']) - day(row['lastStart'])).days + offset
    # 冻结预测时点后不读取后续温度；未来仅推进周期天数。
    recent = [t['deviation'] for t in samples[-3:]]
    previous = [t['deviation'] for t in samples[-10:-3]]
    return [1., (current - st.mean(lengths)) / 10., st.pstdev(lengths) / 10.,
            st.mean(recent) if recent else 0.,
            st.mean(recent) - st.mean(previous) if recent and previous else 0.,
            float(not recent)]

def sigmoid(x):
    return 1 / (1 + math.exp(-max(-40., min(40., x))))

def train(rows, steps=600, regularization=.03):
    examples = []
    for row in rows:
        if row['cohort'] != 'development':
            continue
        for offset in range(row['leadDays'] + 1):
            examples.append((features(row, offset), float(offset == row['leadDays'])))
    if not examples:
        raise ValueError('development_data_required')
    weights = [0.] * 6
    for _ in range(steps):
        gradient = [0.] * 6
        for x, y in examples:
            error = sigmoid(sum(a*b for a, b in zip(weights, x))) - y
            for j in range(6):
                gradient[j] += error * x[j] / len(examples)
        weights = [w - .05 * (g + (regularization*w if j else 0.)) for j, (w, g) in enumerate(zip(weights, gradient))]
    return weights

def baseline(row):
    start = day(row['lastStart'])
    lengths = row['priorLengths'][-6:]
    return start + dt.timedelta(days=min(lengths)), start + dt.timedelta(days=max(lengths))

def forecast(row, weights):
    lo, hi = baseline(row)
    if len(row.get('temperature', [])) < 10:
        return lo, hi, False
    survival, distribution = 1., []
    for offset in range(46):
        hazard = sigmoid(sum(a*b for a, b in zip(weights, features(row, offset))))
        distribution.append(survival * hazard)
        survival *= 1 - hazard
    # 候选无法覆盖未来质量时回退；不能为了分数删除失败周期。
    if sum(distribution) < .9:
        return lo, hi, False
    cumulative, left, right = 0., None, None
    for offset, mass in enumerate(distribution):
        cumulative += mass
        if left is None and cumulative >= .1:
            left = offset
        if right is None and cumulative >= .9:
            right = offset
    if left is None or right is None:
        return lo, hi, False
    start = day(row['asOf'])
    return start + dt.timedelta(days=left), start + dt.timedelta(days=right), True

def assess(data):
    rows = validate(data)
    weights = train(rows)
    tests = [r for r in rows if r['cohort'] == 'test']
    if not tests:
        raise ValueError('independent_test_data_required')
    report = {'modelVersion': MODEL_VERSION, 'released': False, 'trainingParticipants': len({r['participant'] for r in rows if r['cohort']=='development'}), 'testParticipants': len({r['participant'] for r in tests}), 'slices': {}}
    for lead in (3, 7):
        selected = [r for r in tests if r['leadDays']==lead]
        if not selected:
            continue
        measures, by_person = [], {}
        for row in selected:
            actual = day(row['actualStart'])
            a, b = baseline(row)
            c, d, enhanced = forecast(row, weights)
            error_a = abs(((a-actual).days+(b-actual).days)/2)
            error_b = abs(((c-actual).days+(d-actual).days)/2)
            measures.append((error_a,error_b,(b-a).days,(d-c).days,float(a<=actual<=b),float(c<=actual<=d),float(enhanced)))
            by_person.setdefault(row['participant'], []).append(error_b-error_a)
        means = [st.mean(x) for x in zip(*measures)]
        deltas = [st.mean(x) for x in by_person.values()]
        rng = random.Random(20261104)
        bootstrap = sorted(st.mean(rng.choices(deltas,k=len(deltas))) for _ in range(1000))
        report['slices'][str(lead)] = {'cycles':len(selected),'calendarMAE':means[0],'pipelineMAE':means[1],'calendarWidth':means[2],'pipelineWidth':means[3],'calendarCoverage':means[4],'pipelineCoverage':means[5],'enhancedFraction':means[6],'pairedDelta95CI':[bootstrap[24],bootstrap[974]],'engineeringTargetMet':means[1]<=means[0]*.85 and means[3]<=means[2] and means[5]>=means[4] and bootstrap[974]<0}
    # 此文件的结果永远不是生产启用清单，也不自动发布/训练日常会员记录。
    return report

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--input',required=True);parser.add_argument('--output',required=True);args=parser.parse_args()
    with open(args.input,encoding='utf8') as f: result=assess(json.load(f))
    with open(args.output,'x',encoding='utf8') as f: json.dump(result,f,ensure_ascii=False,indent=2)
