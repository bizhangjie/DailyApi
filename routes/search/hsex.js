const Router = require("koa-router");
const hsexRouter = new Router();
const axios = require("axios");
const {get, set, del} = require("../../utils/cacheData");
const response = require('../../utils/response')
const cheerio = require('cheerio');

// 接口信息
const routerInfo = {
    name: "hsex", title: "hsex影视", subtitle: "每日榜", category: ""
};

// 缓存键名
const cacheKey = "hsexData";

// 调用时间
let updateTime = new Date().toISOString();

// 永久导航页（需翻墙）
const Host = "https://hsex.icu";

// 数据处理
const getData = (data) => {
    if (!data) return [];
    try {
        var listData = [];
        const htmlString = data;
        const $ = cheerio.load(htmlString);
        $('.thumbnail').each((index, element) => {
            // 标题
            const articleText = $(element).find('.title').text();
            // 图片地址
            const articleImg = $(element).find('.image').attr('style').replace("background-image: url('", "").replace("')", "");
            // 下载链接
            const articleHref = $(element).find('.title').find('a').attr('href');
            // push日期 + 作者
            // const date = $(element).find('.text-truncate').text().replace("\n",'').replace("\t",'');
            const time = $(element).find('.duration').text();
            // console.log(`Article ${index + 1}: Text: ${articleText}, Href:${articleHref}, Img:${articleImg}, time:${time}`);
            listData.push({
                aid: articleHref,
                title: articleText,
                img: articleImg,
                href: Host + '/' + articleHref,
                time: time
            })
            // console.log(`Article ${index + 1}: Text: ${articleText}, Href:${articleHref.split('/')[3]}, Img:${articleImg}, desc:${desc}`);
        });
        return {
            // count: $('.last-page').first().text(),
            data: listData,
        };
    } catch (error) {
        console.error("数据处理出错" + error);
        return false;
    }
};

// 播放地址
hsexRouter.get("/hsex/:uid", async (ctx) => {
    const {uid} = ctx.params;
    const url = Host + `/${uid}`;
    console.log(`获取hsex播放地址 => ${url}`);
    const key = `${cacheKey}_${uid}`;
    try {
        // 从缓存中获取数据
        let data = await get(key);
        const from = data ? "cache" : "server";
        if (!data) {
            // 如果缓存中不存在数据
            console.log("从服务端重新获取hsex影视播放地址 => " + url);
            // 从服务器拉取数据
            const res = await axios.get(url);
            const ydata = res.data; // 修改此处，将结果赋值给已声明的data变量，而不是重新声明一个新的data变量
            const title = ydata.match(/<h3 class="panel-title">(.+?)</)[1];
            const m3u8 = ydata.match(/<source src="(.+?)"/)[1];
            const img = ydata.match(/poster="(.+?)"/)[1];
            data = {
                title: title,
                m3u8: m3u8,
                img: img
            }
            // 将数据写入缓存
            await set(key, data);
            response(ctx, 200, data, "从远程获取成功");
        } else {
            response(ctx, 200, data, "从缓存获取成功");
        }
    } catch (err) {
        response(ctx, 606, "", "此类数据有毒，但是很好看！");
    }
});

// hsex影视搜索
hsexRouter.get("/hsex/:wd/:page", async (ctx) => {
    const {wd, page} = ctx.params;
    const regex = /^[\u4e00-\u9fa5]{2,}$/; // 正则表达式匹配至少两个中文字符

    if (!regex.test(wd)) {
        ctx.body = "wd 参数必须包含至少两个以上的中文字符";
        return;
    }
    const url = `${Host}/search-${page}.htm?search=${wd}`;
    console.log(`获取hsex影视 ${url}`);
    try {
        // 从缓存中获取数据
        let data = await get(`${cacheKey}_${url}`);
        const from = data ? "cache" : "server";
        if (!data) {
            // 如果缓存中不存在数据
            console.log("从服务端重新获取hsex影视");
            // 从服务器拉取数据
            const response = await axios.get(url);
            data = getData(response.data);
            updateTime = new Date().toISOString();
            if (!data) {
                ctx.body = {
                    code: 500,
                    ...routerInfo,
                    message: "获取失败",
                };
                return false;
            }
            // 将数据写入缓存
            await set(`${cacheKey}_${url}`, data);
        }
        ctx.body = {
            code: 200,
            message: "获取成功",
            ...routerInfo,
            from,
            total: data.length,
            updateTime,
            data,
        };
    } catch (error) {
        console.error(error);
        ctx.body = {
            code: 500,
            message: "获取失败",
        };
    }
});


hsexRouter.info = routerInfo;
module.exports = hsexRouter;
